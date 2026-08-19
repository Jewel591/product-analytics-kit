import Foundation
import Testing
@_spi(Testing) @testable import ProductAnalyticsKit

@MainActor
struct PostHogPolicyTests {
    @Test func optionalPostHogProductsStayDisabled() {
        let policy = PostHogAnalyticsTransport.policySnapshot

        #expect(policy.host == "https://us.i.posthog.com")
        #expect(!policy.lifecycleAutocapture)
        #expect(!policy.screenAutocapture)
        #expect(!policy.swizzling)
        #expect(!policy.featureFlagPreloading)
        #expect(!policy.featureFlagEvents)
        #expect(!policy.defaultPersonProperties)
        #expect(!policy.sessionReplay)
        #expect(!policy.surveys)
        #expect(!policy.errorAutocapture)
        #expect(!policy.pushSubscriptionAutocapture)
        #expect(!policy.pushOpenAutocapture)
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

    @Test func visionOSSkipsUnavailableCrashAutocaptureSetter() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/ProductAnalyticsKit/PostHogAnalyticsTransport.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains(
            "#if !os(visionOS)\n        config.errorTrackingConfig.autoCapture = false\n        #endif"
        ))
    }
}
