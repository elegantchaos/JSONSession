// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "JSONSession",
    
    platforms: [
        .macOS(.v10_15), .macCatalyst(.v13), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "JSONSession",
            targets: ["JSONSession"]),
    ],
    dependencies: [
         .package(url: "https://github.com/elegantchaos/Coercion.git", from: "1.0.3"),
         .package(url: "https://github.com/elegantchaos/DataFetcher.git", from: "1.0.2"),
         .package(url: "https://github.com/elegantchaos/Logger.git", from: "1.5.5"),
         .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.0.0"),
         
         // tools
         .package(url: "https://github.com/elegantchaos/ActionBuilderPlugin.git", from: "1.0.7"),
         .package(url: "https://github.com/elegantchaos/SwiftFormatterPlugin.git", from: "1.0.3"),
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
