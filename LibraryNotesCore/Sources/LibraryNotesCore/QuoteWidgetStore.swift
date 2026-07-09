// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct QuoteWidgetStore {
  public static let appGroupIdentifier = "group.org.brians-brain.grail-diary"
  public static let snapshotFileName = "QuoteOfTheDaySnapshot.json"

  private let fileManager: FileManager
  private let appGroupIdentifier: String
  private let explicitContainerURL: URL?
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(
    fileManager: FileManager = .default,
    appGroupIdentifier: String = Self.appGroupIdentifier,
    containerURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.appGroupIdentifier = appGroupIdentifier
    self.explicitContainerURL = containerURL

    self.encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    self.decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  public var snapshotURL: URL? {
    containerURL?.appendingPathComponent(Self.snapshotFileName, isDirectory: false)
  }

  public func readSnapshot() throws -> QuoteOfTheDaySnapshot {
    guard let snapshotURL else {
      throw QuoteWidgetStoreError.missingAppGroupContainer(appGroupIdentifier)
    }
    guard fileManager.fileExists(atPath: snapshotURL.path) else {
      throw QuoteWidgetStoreError.missingSnapshot(snapshotURL)
    }
    let data = try Data(contentsOf: snapshotURL)
    let snapshot = try decoder.decode(QuoteOfTheDaySnapshot.self, from: data)
    guard snapshot.isReadableByCurrentVersion else {
      throw QuoteWidgetStoreError.unsupportedSchemaVersion(snapshot.schemaVersion)
    }
    return snapshot
  }

  public func writeSnapshot(_ snapshot: QuoteOfTheDaySnapshot) throws {
    guard let containerURL else {
      throw QuoteWidgetStoreError.missingAppGroupContainer(appGroupIdentifier)
    }
    try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
    let data = try encoder.encode(snapshot)
    try data.write(to: containerURL.appendingPathComponent(Self.snapshotFileName, isDirectory: false), options: .atomic)
  }

  private var containerURL: URL? {
    explicitContainerURL ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
  }
}

public enum QuoteWidgetStoreError: LocalizedError, Equatable {
  case missingAppGroupContainer(String)
  case missingSnapshot(URL)
  case unsupportedSchemaVersion(Int)

  public var errorDescription: String? {
    switch self {
    case .missingAppGroupContainer(let identifier):
      "Could not find the app group container for \(identifier)."
    case .missingSnapshot(let url):
      "Could not find the quote widget snapshot at \(url.path)."
    case .unsupportedSchemaVersion(let version):
      "Quote widget snapshot schema version \(version) is not supported."
    }
  }
}
