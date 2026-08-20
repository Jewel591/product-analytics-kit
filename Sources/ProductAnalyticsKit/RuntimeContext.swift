import Foundation

enum RuntimeContext {
    static func properties(bundle: Bundle = .main) -> [String: Any] {
        [
            "app_version":
                bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                    as? String ?? "unknown",
            "app_build":
                bundle.object(forInfoDictionaryKey: "CFBundleVersion")
                    as? String ?? "unknown",
            "os_name": osName,
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
        ]
    }

    private static var osName: String {
        #if os(visionOS)
        "visionos"
        #elseif os(iOS)
        "ios"
        #elseif os(macOS)
        "macos"
        #else
        "unknown"
        #endif
    }
}
