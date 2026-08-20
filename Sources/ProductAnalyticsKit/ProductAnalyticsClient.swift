import Foundation

@MainActor
public final class ProductAnalyticsClient {
    public static let shared = ProductAnalyticsClient()

    private let transport: any ProductAnalyticsTransport
    private let preferences: any ProductAnalyticsPreferenceStoring
    private let lifecycleSource: any ProductAnalyticsLifecycleSourcing
    private let runtimeProperties: @MainActor () -> [String: Any]

    private var projectToken: String?
    private var transportStarted = false
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

        self.projectToken = token
        activateIfIdentityReported()
        return .started
    }

    /// Captures a bounded product event without ever throwing into business code.
    @discardableResult
    public func track(
        name: String,
        properties: [String: AnalyticsPropertyValue] = [:]
    ) -> AnalyticsCaptureOutcome {
        guard projectToken != nil else { return .dropped(.notStarted) }
        guard transportStarted else { return .dropped(.identityNotReported) }
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
        if changed, previousUserID != nil {
            // Persist the conservative reset marker first. A termination
            // between these two writes may cause one extra reset, but can
            // never let a new session inherit the previous provider identity.
            preferences.hasPendingIdentityReset = true
        }
        preferences.authenticatedUserID = userID

        activateIfIdentityReported()

        guard transportStarted, preferences.collectionEnabled else {
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
        activateIfIdentityReported()
        guard transportStarted else { return }

        if !enabled {
            transport.setCollectionEnabled(false)
            return
        }

        // Reset while the provider remains opted out so its persisted queue
        // cannot flush under the previous account identity.
        reconcilePendingIdentityResetIfNeeded()
        transport.setCollectionEnabled(true)
        identifyReportedUserIfNeeded()
    }

    @discardableResult
    private func reconcilePendingIdentityResetIfNeeded() -> Bool {
        guard preferences.hasPendingIdentityReset,
              transportStarted,
              preferences.collectionEnabled
        else {
            return false
        }

        transport.reset()
        identifiedUserID = nil
        preferences.hasPendingIdentityReset = false
        return true
    }

    /// Starts the provider only after the host has supplied current session
    /// truth, including an explicit nil for an anonymous session. This keeps
    /// launch and early product events off a persisted identity from a prior
    /// process. A pending reset starts opted out until the old queue and
    /// identity have been cleared.
    private func activateIfIdentityReported() {
        guard !transportStarted,
              hasReportedIdentity,
              let projectToken
        else {
            return
        }

        let startsEnabled = preferences.collectionEnabled
            && !preferences.hasPendingIdentityReset
        transport.start(
            projectToken: projectToken,
            collectionEnabled: startsEnabled
        )
        transportStarted = true

        if preferences.collectionEnabled,
           reconcilePendingIdentityResetIfNeeded() {
            transport.setCollectionEnabled(true)
        }
        identifyReportedUserIfNeeded()

        lifecycleSource.eventHandler = { [weak self] event in
            self?.record(event)
        }
        lifecycleSource.start()
        captureStudioEvent("studio_app_launched")
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
        if preferences.collectionEnabled, transportStarted {
            transport.flush()
        }
    }

    private func captureStudioEvent(_ name: String) {
        guard transportStarted, preferences.collectionEnabled,
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
