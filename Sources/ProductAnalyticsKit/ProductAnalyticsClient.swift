import Foundation

@MainActor
public final class ProductAnalyticsClient {
    public static let shared = ProductAnalyticsClient()

    private let transport: any ProductAnalyticsTransport
    private let preferences: any ProductAnalyticsPreferenceStoring
    private let lifecycleSource: any ProductAnalyticsLifecycleSourcing
    private let runtimeProperties: @MainActor () -> [String: AnalyticsPropertyValue]

    private var projectToken: String?
    private var pendingUserID: String?

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
        runtimeProperties: @escaping @MainActor () -> [String: AnalyticsPropertyValue]
    ) {
        self.transport = transport
        self.preferences = preferences
        self.lifecycleSource = lifecycleSource
        self.runtimeProperties = runtimeProperties
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

        if preferences.hasPendingIdentityReset {
            transport.setCollectionEnabled(true)
            transport.reset()
            preferences.hasPendingIdentityReset = false
            if !preferences.collectionEnabled {
                transport.setCollectionEnabled(false)
            }
        }

        if preferences.collectionEnabled, let pendingUserID {
            transport.identify(userID: pendingUserID)
        }

        lifecycleSource.eventHandler = { [weak self] event in
            self?.record(event)
        }
        lifecycleSource.start()
        captureStudioEvent("studio_app_launched")
        return .started
    }

    @discardableResult
    public func track(_ event: AnalyticsEvent) -> AnalyticsCaptureOutcome {
        guard projectToken != nil else { return .dropped(.notStarted) }
        guard preferences.collectionEnabled else {
            return .dropped(.collectionDisabled)
        }
        transport.capture(
            event: event.name,
            properties: event.properties.mapValues(\.transportValue)
        )
        return .captured
    }

    @discardableResult
    public func identify(userID rawUserID: String) -> AnalyticsIdentityOutcome {
        do {
            try AnalyticsValidation.validateUserID(rawUserID)
        } catch {
            return .rejected
        }

        pendingUserID = rawUserID
        guard projectToken != nil, preferences.collectionEnabled else {
            return .deferred
        }
        transport.identify(userID: rawUserID)
        return .identified
    }

    public func reset() {
        pendingUserID = nil
        guard projectToken != nil else {
            preferences.hasPendingIdentityReset = true
            return
        }
        guard preferences.collectionEnabled else {
            preferences.hasPendingIdentityReset = true
            return
        }
        transport.reset()
        preferences.hasPendingIdentityReset = false
    }

    public func setCollectionEnabled(_ enabled: Bool) {
        guard preferences.collectionEnabled != enabled else { return }
        preferences.collectionEnabled = enabled
        guard projectToken != nil else { return }

        transport.setCollectionEnabled(enabled)
        guard enabled else { return }

        if preferences.hasPendingIdentityReset {
            transport.reset()
            preferences.hasPendingIdentityReset = false
        }
        if let pendingUserID {
            transport.identify(userID: pendingUserID)
        }
    }

    private func record(_ event: ProductAnalyticsLifecycleEvent) {
        switch event {
        case .becameActive:
            captureStudioEvent("studio_app_became_active")
        case .enteredBackground:
            captureStudioEvent("studio_app_entered_background")
            if preferences.collectionEnabled, projectToken != nil {
                transport.flush()
            }
        }
    }

    private func captureStudioEvent(_ name: String) {
        guard projectToken != nil, preferences.collectionEnabled,
              let event = try? AnalyticsEvent(
                  studioEvent: name,
                  properties: runtimeProperties()
              )
        else {
            return
        }
        transport.capture(
            event: event.name,
            properties: event.properties.mapValues(\.transportValue)
        )
    }
}
