import Foundation

enum RuntimeContext {
    static func properties(bundle: Bundle = .main) -> [String: AnalyticsPropertyValue] {
        [
            "app_version": .string(
                bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                    as? String ?? "unknown"
            ),
            "app_build": .string(
                bundle.object(forInfoDictionaryKey: "CFBundleVersion")
                    as? String ?? "unknown"
            ),
            "os_name": .string(osName),
            "os_version": .string(ProcessInfo.processInfo.operatingSystemVersionString),
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
