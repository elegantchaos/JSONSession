// swift-tools-version:6.2

import PackageDescription

let package = Package(
  name: "JSONSession",

  platforms: [
    .macOS(.v15), .macCatalyst(.v18), .iOS(.v18), .tvOS(.v18), .watchOS(.v11),
  ],
  products: [
    .library(
      name: "JSONSession",
      targets: ["JSONSession"])
  ],
  dependencies: [
    .package(url: "https://github.com/elegantchaos/DataFetcher.git", from: "1.0.2"),
    .package(url: "https://github.com/elegantchaos/Logger.git", from: "2.0.1"),

    // tools
    .package(url: "https://github.com/elegantchaos/ActionBuilderPlugin.git", from: "2.0.1"),
  ],
  targets: [
    .target(
      name: "JSONSession",
      dependencies: ["DataFetcher", "Logger"]
    ),
    .testTarget(
      name: "JSONSessionTests",
      dependencies: ["JSONSession"]
    ),
  ]
)
