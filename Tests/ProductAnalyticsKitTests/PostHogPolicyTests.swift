import Foundation
import PostHog
import Testing
@_spi(Testing) @testable import ProductAnalyticsKit

@MainActor
struct PostHogPolicyTests {
    @Test func realConfigurationDisablesOptionalPostHogProducts() {
        let config = PostHogAnalyticsTransport.makeConfiguration(
            projectToken: validProjectToken,
            collectionEnabled: false
        )

        #expect(config.host.absoluteString == "https://us.i.posthog.com")
        #expect(!config.captureApplicationLifecycleEvents)
        #expect(!config.captureScreenViews)
        #expect(!config.enableSwizzling)
        #expect(!config.preloadFeatureFlags)
        #expect(!config.sendFeatureFlagEvent)
        #expect(!config.setDefaultPersonProperties)
        #expect(config.personProfiles == .identifiedOnly)
        #expect(config.optOut)

        #if os(iOS) || targetEnvironment(macCatalyst)
        #expect(!config.captureElementInteractions)
        #expect(!config.rageClickConfig.enabled)
        #expect(!config.sessionReplay)
        #expect(!config.surveys)
        #endif

        #if os(iOS) || os(macOS)
        #expect(!config.capturePushNotificationSubscriptions)
        #expect(!config.capturePushNotificationOpened)
        #endif

        #if !os(visionOS)
        #expect(!config.errorTrackingConfig.autoCapture)
        #endif
    }

    @Test func providerEventFirewallAllowsOnlyKitAndIdentityEvents() {
        #expect(PostHogAnalyticsTransport.allowsProviderEventName("reminder_created"))
        #expect(PostHogAnalyticsTransport.allowsProviderEventName("studio_app_launched"))
        #expect(PostHogAnalyticsTransport.allowsProviderEventName("$identify"))
        #expect(PostHogAnalyticsTransport.allowsProviderEventName("$set"))
        #expect(!PostHogAnalyticsTransport.allowsProviderEventName("$screen"))
        #expect(!PostHogAnalyticsTransport.allowsProviderEventName("$exception"))
        #expect(!PostHogAnalyticsTransport.allowsProviderEventName("Application Opened"))
    }

    @Test func kitPreferenceWinsAfterProviderRestoresItsOwnOptOut() {
        let enabledRuntime = FakePostHogRuntime()
        PostHogAnalyticsTransport(runtime: enabledRuntime).start(
            projectToken: validProjectToken,
            collectionEnabled: true
        )
        #expect(enabledRuntime.actions == ["setup:false", "optIn"])

        let disabledRuntime = FakePostHogRuntime()
        PostHogAnalyticsTransport(runtime: disabledRuntime).start(
            projectToken: validProjectToken,
            collectionEnabled: false
        )
        #expect(disabledRuntime.actions == ["setup:true", "optOut"])
    }

    @Test func privacyManifestDeclaresLinkedAnalyticsWithoutTracking() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifestURL = repositoryRoot
            .appendingPathComponent("Sources/ProductAnalyticsKit/Resources/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: manifestURL)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )

        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let collected = try #require(
            plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        )
        let types = Set(collected.compactMap {
            $0["NSPrivacyCollectedDataType"] as? String
        })
        #expect(types == [
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeDeviceID",
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeOtherUsageData",
        ])
        #expect(collected.allSatisfy {
            $0["NSPrivacyCollectedDataTypeLinked"] as? Bool == true
                && $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false
        })
    }
}

@MainActor
private final class FakePostHogRuntime: PostHogRuntime {
    var actions: [String] = []

    func setup(_ configuration: PostHogConfig) {
        actions.append("setup:\(configuration.optOut)")
    }

    func capture(_ event: String, properties: [String: Any]) {
        actions.append("capture:\(event)")
    }

    func identify(_ userID: String) {
        actions.append("identify:\(userID)")
    }

    func reset() {
        actions.append("reset")
    }

    func optIn() {
        actions.append("optIn")
    }

    func optOut() {
        actions.append("optOut")
    }

    func flush() {
        actions.append("flush")
    }
}
