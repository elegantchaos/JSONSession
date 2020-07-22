// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "JSONSession",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v5)
    ],
    products: [
        .library(
            name: "JSONSession",
            targets: ["JSONSession"]),
    ],
    dependencies: [
         .package(url: "https://github.com/elegantchaos/Coercion.git", from: "1.0.0"),
         .package(url: "https://github.com/elegantchaos/DataFetcher.git", from: "1.0.2"),
         .package(url: "https://github.com/elegantchaos/Logger.git", from: "1.5.5"),
         .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "JSONSession",
            dependencies: ["Coercion", "DataFetcher", "Logger"]
        ),
        .testTarget(
            name: "JSONSessionTests",
            dependencies: ["JSONSession", "XCTestExtensions"]
        ),
    ]
)
