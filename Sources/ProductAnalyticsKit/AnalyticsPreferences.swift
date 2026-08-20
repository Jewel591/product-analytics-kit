import Foundation

@MainActor
final class UserDefaultsAnalyticsPreferenceStore: ProductAnalyticsPreferenceStoring {
    private enum Key {
        static let collectionEnabled =
            "com.jewel591.ProductAnalyticsKit.collectionEnabled.v1"
        static let pendingIdentityReset =
            "com.jewel591.ProductAnalyticsKit.pendingIdentityReset.v1"
        static let authenticatedUserID =
            "com.jewel591.ProductAnalyticsKit.authenticatedUserID.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var collectionEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.collectionEnabled) != nil else {
                return true
            }
            return defaults.bool(forKey: Key.collectionEnabled)
        }
        set { defaults.set(newValue, forKey: Key.collectionEnabled) }
    }

    var isCollectionPreferenceInitialized: Bool {
        defaults.object(forKey: Key.collectionEnabled) != nil
    }

    var hasPendingIdentityReset: Bool {
        get { defaults.bool(forKey: Key.pendingIdentityReset) }
        set { defaults.set(newValue, forKey: Key.pendingIdentityReset) }
    }

    var authenticatedUserID: UUID? {
        get {
            guard let value = defaults.string(forKey: Key.authenticatedUserID) else {
                return nil
            }
            return UUID(uuidString: value)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Key.authenticatedUserID)
        }
    }
}
