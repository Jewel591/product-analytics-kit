// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProductAnalyticsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ProductAnalyticsKit", targets: ["ProductAnalyticsKit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PostHog/posthog-ios.git",
            from: "3.69.8"
        ),
    ],
    targets: [
        .target(
            name: "ProductAnalyticsKit",
            dependencies: [
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ProductAnalyticsKitTests",
            dependencies: ["ProductAnalyticsKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
