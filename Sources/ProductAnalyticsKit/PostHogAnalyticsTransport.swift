import Foundation
import PostHog

@MainActor
protocol PostHogRuntime: AnyObject {
    func setup(_ configuration: PostHogConfig)
    func capture(_ event: String, properties: [String: Any])
    func identify(_ userID: String)
    func reset()
    func optIn()
    func optOut()
    func flush()
}

@MainActor
private final class SharedPostHogRuntime: PostHogRuntime {
    func setup(_ configuration: PostHogConfig) {
        PostHogSDK.shared.setup(configuration)
    }

    func capture(_ event: String, properties: [String: Any]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    func identify(_ userID: String) {
        PostHogSDK.shared.identify(userID)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }

    func optIn() {
        PostHogSDK.shared.optIn()
    }

    func optOut() {
        PostHogSDK.shared.optOut()
    }

    func flush() {
        PostHogSDK.shared.flush()
    }
}

@MainActor
final class PostHogAnalyticsTransport: ProductAnalyticsTransport {
    static let host = "https://us.i.posthog.com"

    private let runtime: any PostHogRuntime

    init(runtime: any PostHogRuntime = SharedPostHogRuntime()) {
        self.runtime = runtime
    }

    static func makeConfiguration(
        projectToken: String,
        collectionEnabled: Bool
    ) -> PostHogConfig {
        let config = PostHogConfig(projectToken: projectToken, host: host)
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
        config.rageClickConfig.enabled = false
        config.sessionReplay = false
        config.surveys = false
        #endif

        #if os(iOS) || os(macOS)
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        #endif

        config.setBeforeSend { event in
            allowsProviderEventName(event.event) ? event : nil
        }
        config.logs.setBeforeSend { _ in nil }
        return config
    }

    static func allowsProviderEventName(_ name: String) -> Bool {
        if name == "$identify" || name == "$set" {
            return true
        }
        return (try? AnalyticsValidation.validateEventName(
            name,
            allowsStudioPrefix: true
        )) != nil
    }

    func start(projectToken: String, collectionEnabled: Bool) {
        runtime.setup(Self.makeConfiguration(
            projectToken: projectToken,
            collectionEnabled: collectionEnabled
        ))

        // PostHog restores its own persisted opt-out after setup. The Kit's
        // preference is the only portfolio truth, so reconcile unconditionally.
        setCollectionEnabled(collectionEnabled)
    }

    func capture(event: String, properties: [String: Any]) {
        runtime.capture(event, properties: properties)
    }

    func identify(userID: String) {
        runtime.identify(userID)
    }

    func reset() {
        runtime.reset()
    }

    func setCollectionEnabled(_ enabled: Bool) {
        if enabled {
            runtime.optIn()
        } else {
            runtime.optOut()
        }
    }

    func flush() {
        runtime.flush()
    }
}
