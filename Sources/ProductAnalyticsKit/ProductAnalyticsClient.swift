import Foundation

@MainActor
public final class ProductAnalyticsClient {
    public static let shared = ProductAnalyticsClient()

    private let transport: any ProductAnalyticsTransport
    private let preferences: any ProductAnalyticsPreferenceStoring
    private let lifecycleSource: any ProductAnalyticsLifecycleSourcing
    private let runtimeProperties: @MainActor () -> [String: Any]

    private var projectToken: String?
    private var reportedUserID: UUID?
    private var hasReportedIdentity = false
    private var identifiedUserID: UUID?

    public var isCollectionEnabled: Bool {
        preferences.collectionEnabled
    }

    private convenience init() {
        self.init(
            transport: PostHogAnalyticsTransport(),
            preferences: UserDefaultsAnalyticsPreferenceStore(),
            lifecycleSource: SystemLifecycleSource(),
            runtimeProperties: { RuntimeContext.properties() }
        )
    }

    @_spi(Testing)
    public init(
        transport: any ProductAnalyticsTransport,
        preferences: any ProductAnalyticsPreferenceStoring,
        lifecycleSource: any ProductAnalyticsLifecycleSourcing,
        runtimeProperties: @escaping @MainActor () -> [String: Any]
    ) {
        self.transport = transport
        self.preferences = preferences
        self.lifecycleSource = lifecycleSource
        self.runtimeProperties = runtimeProperties
    }

    /// Seeds a legacy user choice exactly once, before analytics starts.
    /// No host-owned migration marker is needed.
    @discardableResult
    public func seedCollectionPreferenceIfUnset(legacyValue: Bool) -> Bool {
        guard projectToken == nil,
              !preferences.isCollectionPreferenceInitialized
        else {
            return false
        }
        preferences.collectionEnabled = legacyValue
        return true
    }

    @discardableResult
    public func start(projectToken rawToken: String) -> AnalyticsStartOutcome {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AnalyticsValidation.validateProjectToken(token) else {
            return .rejected(.invalidProjectToken)
        }
        if let projectToken {
            return projectToken == token
                ? .alreadyStarted
                : .rejected(.differentProjectToken)
        }

        let shouldStartEnabled = preferences.collectionEnabled
            && !preferences.hasPendingIdentityReset
        transport.start(
            projectToken: token,
            collectionEnabled: shouldStartEnabled
        )
        self.projectToken = token

        reconcilePendingIdentityResetIfNeeded()
        identifyReportedUserIfNeeded()

        lifecycleSource.eventHandler = { [weak self] event in
            self?.record(event)
        }
        lifecycleSource.start()
        captureStudioEvent("studio_app_launched")
        return .started
    }

    /// Captures a bounded product event without ever throwing into business code.
    @discardableResult
    public func track(
        name: String,
        properties: [String: AnalyticsPropertyValue] = [:]
    ) -> AnalyticsCaptureOutcome {
        guard projectToken != nil else { return .dropped(.notStarted) }
        guard preferences.collectionEnabled else {
            return .dropped(.collectionDisabled)
        }
        guard (try? AnalyticsValidation.validateEventName(
            name,
            allowsStudioPrefix: false
        )) != nil,
        (try? AnalyticsValidation.validateProperties(properties)) != nil
        else {
            return .dropped(.invalidSchema)
        }

        transport.capture(
            event: name,
            properties: properties.mapValues(\.transportValue)
        )
        return .captured
    }

    /// Applies the current authenticated session identity. Passing a different
    /// UUID resets the previous identity before identifying the new account;
    /// passing nil performs logout reset.
    @discardableResult
    public func setAuthenticatedUserID(
        _ userID: UUID?
    ) -> AnalyticsIdentityOutcome {
        hasReportedIdentity = true
        reportedUserID = userID

        let previousUserID = preferences.authenticatedUserID
        let changed = previousUserID != userID
        preferences.authenticatedUserID = userID
        if changed, previousUserID != nil {
            preferences.hasPendingIdentityReset = true
        }

        guard projectToken != nil, preferences.collectionEnabled else {
            return changed || identifiedUserID != userID ? .deferred : .unchanged
        }

        let resetApplied = reconcilePendingIdentityResetIfNeeded()
        if let userID, identifiedUserID != userID {
            transport.identify(userID: userID.uuidString)
            identifiedUserID = userID
            return .applied
        }
        if userID == nil {
            identifiedUserID = nil
        }
        return resetApplied ? .applied : .unchanged
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        guard preferences.collectionEnabled != enabled else { return }
        preferences.collectionEnabled = enabled
        guard projectToken != nil else { return }

        transport.setCollectionEnabled(enabled)
        guard enabled else { return }

        reconcilePendingIdentityResetIfNeeded()
        identifyReportedUserIfNeeded()
    }

    @discardableResult
    private func reconcilePendingIdentityResetIfNeeded() -> Bool {
        guard preferences.hasPendingIdentityReset,
              projectToken != nil
        else {
            return false
        }

        // Startup deliberately remains opted out while a persisted identity
        // reset is pending. Temporarily opt in so transports such as PostHog do
        // not discard the reset operation, then restore the user's preference.
        let shouldRestoreDisabled = !preferences.collectionEnabled
        transport.setCollectionEnabled(true)
        transport.reset()
        identifiedUserID = nil
        preferences.hasPendingIdentityReset = false
        if shouldRestoreDisabled {
            transport.setCollectionEnabled(false)
        }
        return true
    }

    private func identifyReportedUserIfNeeded() {
        guard hasReportedIdentity,
              preferences.collectionEnabled,
              projectToken != nil,
              let reportedUserID,
              identifiedUserID != reportedUserID
        else {
            return
        }
        transport.identify(userID: reportedUserID.uuidString)
        identifiedUserID = reportedUserID
    }

    private func record(_ event: ProductAnalyticsLifecycleEvent) {
        switch event {
        case .becameActive:
            captureStudioEvent("studio_app_became_active")
        case .enteredBackground:
            captureStudioEvent("studio_app_entered_background")
            flushIfEnabled()
        case .becameInactive:
            captureStudioEvent("studio_app_became_inactive")
            flushIfEnabled()
        }
    }

    private func flushIfEnabled() {
        if preferences.collectionEnabled, projectToken != nil {
            transport.flush()
        }
    }

    private func captureStudioEvent(_ name: String) {
        guard projectToken != nil, preferences.collectionEnabled,
              (try? AnalyticsValidation.validateEventName(
                  name,
                  allowsStudioPrefix: true
              )) != nil
        else {
            return
        }
        transport.capture(event: name, properties: runtimeProperties())
    }
}
