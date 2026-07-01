// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "dogeared",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(
      name: "dogeared",
      targets: ["dogeared"]
    ),
  ],
  dependencies: [
    .package(path: "/Users/brian/TextMarkupKit"),
    .package(url: "https://github.com/bdewey/KeyValueCRDT", .upToNextMajor(from: "1.4.0")),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.6.0")),
  ],
  targets: [
    .executableTarget(
      name: "dogeared",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "KeyValueCRDT", package: "KeyValueCRDT"),
        .product(name: "TextMarkupKit", package: "TextMarkupKit"),
      ]
    ),
  ]
)
