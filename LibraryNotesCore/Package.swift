// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "LibraryNotesCore",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "LibraryNotesCore",
      targets: ["LibraryNotesCore"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/bdewey/BookKit", .upToNextMajor(from: "0.7.0")),
    .package(url: "https://github.com/bdewey/KeyValueCRDT", .upToNextMajor(from: "1.4.0")),
    .package(url: "https://github.com/bdewey/SpacedRepetitionScheduler.git", .upToNextMajor(from: "0.5.0")),
    .package(url: "https://github.com/bdewey/TextMarkupKit", .upToNextMajor(from: "0.12.0")),
    .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.5.0")),
  ],
  targets: [
    .target(
      name: "LibraryNotesCore",
      dependencies: [
        .product(name: "BookKit", package: "BookKit"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "KeyValueCRDT", package: "KeyValueCRDT"),
        .product(name: "SpacedRepetitionScheduler", package: "SpacedRepetitionScheduler"),
        .product(name: "TextMarkupKit", package: "TextMarkupKit"),
      ],
      path: "Sources/LibraryNotesCore"
    ),
  ]
)
