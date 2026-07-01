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
    .package(path: "../LibraryNotesCore"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.6.0")),
  ],
  targets: [
    .executableTarget(
      name: "dogeared",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "LibraryNotesCore",
      ]
    ),
  ]
)
