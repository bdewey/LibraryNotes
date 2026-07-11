// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "LibraryNotesUI",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "LibraryNotesUI",
      targets: ["LibraryNotesUI"]
    ),
  ],
  dependencies: [
    .package(path: "../LibraryNotesCore"),
    .package(url: "https://github.com/bdewey/TextMarkupKit", .upToNextMajor(from: "0.12.0")),
  ],
  targets: [
    .target(
      name: "LibraryNotesUI",
      dependencies: [
        "LibraryNotesCore",
        .product(name: "TextMarkupKit", package: "TextMarkupKit"),
      ],
      path: "Sources/LibraryNotesUI"
    ),
    .testTarget(
      name: "LibraryNotesUITests",
      dependencies: ["LibraryNotesUI"],
      path: "Tests/LibraryNotesUITests"
    ),
  ]
)
