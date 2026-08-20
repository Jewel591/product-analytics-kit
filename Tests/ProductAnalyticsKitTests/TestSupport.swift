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
    var writes: [String] = []
    var collectionEnabled: Bool {
        didSet { isCollectionPreferenceInitialized = true }
    }
    var isCollectionPreferenceInitialized: Bool
    var hasPendingIdentityReset: Bool {
        didSet { writes.append("pending:\(hasPendingIdentityReset)") }
    }
    var authenticatedUserID: UUID? {
        didSet { writes.append("identity:\(authenticatedUserID?.uuidString ?? "nil")") }
    }

    init(
        collectionEnabled: Bool = true,
        isCollectionPreferenceInitialized: Bool = true,
        hasPendingIdentityReset: Bool = false,
        authenticatedUserID: UUID? = nil
    ) {
        self.collectionEnabled = collectionEnabled
        self.isCollectionPreferenceInitialized = isCollectionPreferenceInitialized
        self.hasPendingIdentityReset = hasPendingIdentityReset
        self.authenticatedUserID = authenticatedUserID
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
                "app_version": "1.2.3",
                "app_build": "45",
                "os_name": "ios",
                "os_version": "27.0",
            ]
        }
    )
}

let validProjectToken = "phc_1234567890abcdef"
