// swift-tools-version:6.2

import PackageDescription

let package = Package(
  name: "JSONSession",

  platforms: [
    .macOS(.v26), .macCatalyst(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v11),
  ],
  products: [
    .library(
      name: "JSONSession",
      targets: ["JSONSession"])
  ],
  dependencies: [
    .package(url: "https://github.com/elegantchaos/Logger.git", from: "2.0.1"),

    // tools
    .package(url: "https://github.com/elegantchaos/ActionBuilderPlugin.git", from: "2.1.0"),
  ],
  targets: [
    .target(
      name: "JSONSession",
      dependencies: ["Logger"]
    ),
    .testTarget(
      name: "JSONSessionTests",
      dependencies: ["JSONSession"]
    ),
  ]
)
