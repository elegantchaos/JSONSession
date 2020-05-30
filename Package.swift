// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "JSONSession",
    platforms: [
        .macOS(.v10_15), .iOS(.v12), .tvOS(.v12), .watchOS(.v5)
    ],
    products: [
        .library(
            name: "JSONSession",
            targets: ["JSONSession"]),
    ],
    dependencies: [
         .package(url: "https://github.com/elegantchaos/CollectionExtensions", from: "1.0.0"),
         .package(url: "https://github.com/elegantchaos/Coercion", from: "1.0.0"),
         .package(url: "https://github.com/elegantchaos/Logger", from: "1.5.5"),
         .package(url: "https://github.com/elegantchaos/XCTestExtensions", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "JSONSession",
            dependencies: ["Coercion", "CollectionExtensions", "Logger"]),
        .testTarget(
            name: "JSONSessionTests",
            dependencies: ["JSONSession", "XCTestExtensions"]),
    ]
)
