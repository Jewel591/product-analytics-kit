import Foundation

@_spi(Testing)
@MainActor
public protocol ProductAnalyticsTransport: AnyObject {
    func start(projectToken: String, collectionEnabled: Bool)
    func capture(event: String, properties: [String: Any])
    func identify(userID: String)
    func reset()
    func setCollectionEnabled(_ enabled: Bool)
    func flush()
}

@_spi(Testing)
@MainActor
public protocol ProductAnalyticsPreferenceStoring: AnyObject {
    var collectionEnabled: Bool { get set }
    var isCollectionPreferenceInitialized: Bool { get }
    var hasPendingIdentityReset: Bool { get set }
    var authenticatedUserID: UUID? { get set }
}

@_spi(Testing)
public enum ProductAnalyticsLifecycleEvent: Sendable, Equatable {
    case becameActive
    case enteredBackground
    case becameInactive
}

@_spi(Testing)
@MainActor
public protocol ProductAnalyticsLifecycleSourcing: AnyObject {
    var eventHandler: ((ProductAnalyticsLifecycleEvent) -> Void)? { get set }
    func start()
}
