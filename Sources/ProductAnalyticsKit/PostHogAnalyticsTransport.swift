import Foundation
import PostHog

@_spi(Testing)
public struct PostHogPolicySnapshot: Sendable, Equatable {
    public let host: String
    public let lifecycleAutocapture: Bool
    public let screenAutocapture: Bool
    public let swizzling: Bool
    public let featureFlagPreloading: Bool
    public let featureFlagEvents: Bool
    public let defaultPersonProperties: Bool
    public let sessionReplay: Bool
    public let surveys: Bool
    public let errorAutocapture: Bool
    public let pushSubscriptionAutocapture: Bool
    public let pushOpenAutocapture: Bool

    public init(
        host: String,
        lifecycleAutocapture: Bool,
        screenAutocapture: Bool,
        swizzling: Bool,
        featureFlagPreloading: Bool,
        featureFlagEvents: Bool,
        defaultPersonProperties: Bool,
        sessionReplay: Bool,
        surveys: Bool,
        errorAutocapture: Bool,
        pushSubscriptionAutocapture: Bool,
        pushOpenAutocapture: Bool
    ) {
        self.host = host
        self.lifecycleAutocapture = lifecycleAutocapture
        self.screenAutocapture = screenAutocapture
        self.swizzling = swizzling
        self.featureFlagPreloading = featureFlagPreloading
        self.featureFlagEvents = featureFlagEvents
        self.defaultPersonProperties = defaultPersonProperties
        self.sessionReplay = sessionReplay
        self.surveys = surveys
        self.errorAutocapture = errorAutocapture
        self.pushSubscriptionAutocapture = pushSubscriptionAutocapture
        self.pushOpenAutocapture = pushOpenAutocapture
    }
}

@MainActor
final class PostHogAnalyticsTransport: ProductAnalyticsTransport {
    static let host = "https://us.i.posthog.com"

    static let policySnapshot = PostHogPolicySnapshot(
        host: host,
        lifecycleAutocapture: false,
        screenAutocapture: false,
        swizzling: false,
        featureFlagPreloading: false,
        featureFlagEvents: false,
        defaultPersonProperties: false,
        sessionReplay: false,
        surveys: false,
        errorAutocapture: false,
        pushSubscriptionAutocapture: false,
        pushOpenAutocapture: false
    )

    func start(projectToken: String, collectionEnabled: Bool) {
        let config = PostHogConfig(projectToken: projectToken, host: Self.host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false
        config.personProfiles = .identifiedOnly

        #if !os(visionOS)
        config.errorTrackingConfig.autoCapture = false
        #endif

        config.optOut = !collectionEnabled

        #if os(iOS) || targetEnvironment(macCatalyst)
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        #endif

        #if os(iOS) || os(macOS)
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        #endif

        PostHogSDK.shared.setup(config)
    }

    func capture(event: String, properties: [String: Any]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    func identify(userID: String) {
        PostHogSDK.shared.identify(userID)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }

    func setCollectionEnabled(_ enabled: Bool) {
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    func flush() {
        PostHogSDK.shared.flush()
    }
}
