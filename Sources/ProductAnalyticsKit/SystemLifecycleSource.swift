import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class SystemLifecycleSource: NSObject, ProductAnalyticsLifecycleSourcing {
    var eventHandler: ((ProductAnalyticsLifecycleEvent) -> Void)?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #elseif canImport(AppKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeInactive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func didBecomeActive() {
        eventHandler?(.becameActive)
    }

    @objc private func didEnterBackground() {
        eventHandler?(.enteredBackground)
    }

    @objc private func didBecomeInactive() {
        eventHandler?(.becameInactive)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
