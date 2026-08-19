import Foundation
import Testing
@_spi(Testing) @testable import ProductAnalyticsKit

@MainActor
final class FakeAnalyticsTransport: ProductAnalyticsTransport {
    struct Start {
        let token: String
        let enabled: Bool
    }

    struct Capture {
        let event: String
        let properties: [String: Any]
    }

    var starts: [Start] = []
    var captures: [Capture] = []
    var identifiedUserIDs: [String] = []
    var resetCount = 0
    var collectionEnabledCalls: [Bool] = []
    var flushCount = 0
    var actions: [String] = []

    func start(projectToken: String, collectionEnabled: Bool) {
        starts.append(Start(token: projectToken, enabled: collectionEnabled))
        actions.append("start:\(collectionEnabled)")
    }

    func capture(event: String, properties: [String: Any]) {
        captures.append(Capture(event: event, properties: properties))
        actions.append("capture:\(event)")
    }

    func identify(userID: String) {
        identifiedUserIDs.append(userID)
        actions.append("identify:\(userID)")
    }

    func reset() {
        resetCount += 1
        actions.append("reset")
    }

    func setCollectionEnabled(_ enabled: Bool) {
        collectionEnabledCalls.append(enabled)
        actions.append("enabled:\(enabled)")
    }

    func flush() {
        flushCount += 1
        actions.append("flush")
    }
}

@MainActor
final class FakeAnalyticsPreferences: ProductAnalyticsPreferenceStoring {
    var collectionEnabled: Bool
    var hasPendingIdentityReset: Bool

    init(collectionEnabled: Bool = true, hasPendingIdentityReset: Bool = false) {
        self.collectionEnabled = collectionEnabled
        self.hasPendingIdentityReset = hasPendingIdentityReset
    }
}

@MainActor
final class FakeLifecycleSource: ProductAnalyticsLifecycleSourcing {
    var eventHandler: ((ProductAnalyticsLifecycleEvent) -> Void)?
    var startCount = 0

    func start() {
        startCount += 1
    }

    func send(_ event: ProductAnalyticsLifecycleEvent) {
        eventHandler?(event)
    }
}

@MainActor
func makeClient(
    transport: FakeAnalyticsTransport = FakeAnalyticsTransport(),
    preferences: FakeAnalyticsPreferences = FakeAnalyticsPreferences(),
    lifecycle: FakeLifecycleSource = FakeLifecycleSource()
) -> ProductAnalyticsClient {
    ProductAnalyticsClient(
        transport: transport,
        preferences: preferences,
        lifecycleSource: lifecycle,
        runtimeProperties: {
            [
                "app_version": .string("1.2.3"),
                "app_build": .string("45"),
                "os_name": .string("ios"),
                "os_version": .string("27.0"),
            ]
        }
    )
}

let validProjectToken = "phc_1234567890abcdef"
