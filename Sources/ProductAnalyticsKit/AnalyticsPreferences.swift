import Foundation

@MainActor
final class UserDefaultsAnalyticsPreferenceStore: ProductAnalyticsPreferenceStoring {
    private enum Key {
        static let collectionEnabled =
            "com.jewel591.ProductAnalyticsKit.collectionEnabled.v1"
        static let pendingIdentityReset =
            "com.jewel591.ProductAnalyticsKit.pendingIdentityReset.v1"
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

    var hasPendingIdentityReset: Bool {
        get { defaults.bool(forKey: Key.pendingIdentityReset) }
        set { defaults.set(newValue, forKey: Key.pendingIdentityReset) }
    }
}
