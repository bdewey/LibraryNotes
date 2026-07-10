// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// The app-group database that projects the preferred library for the quote widget.
///
/// This database is intentionally separate from the user's `.libnotes` document.
/// The app refreshes it as a single transaction, while the widget reads only the
/// quote rows needed for its timeline.
public struct QuoteWidgetStore {
  public static let appGroupIdentifier = "group.org.brians-brain.grail-diary"
  public static let databaseFileName = "QuoteOfTheDay.sqlite"
  public static let preferredLibraryBookmarkDataKey = "preferredLibraryBookmarkData"
  public static let preferredLibraryDisplayNameKey = "preferredLibraryDisplayName"

  private let fileManager: FileManager
  private let appGroupIdentifier: String
  private let explicitContainerURL: URL?

  public init(
    fileManager: FileManager = .default,
    appGroupIdentifier: String = Self.appGroupIdentifier,
    containerURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.appGroupIdentifier = appGroupIdentifier
    self.explicitContainerURL = containerURL
  }

  public var databaseURL: URL? {
    containerURL?.appendingPathComponent(Self.databaseFileName, isDirectory: false)
  }

  public func replaceQuotes(
    sourceLibraryDisplayName: String,
    cacheTimestamp: Date,
    candidates: [QuoteWidgetCandidate]
  ) throws {
    guard let databaseURL else {
      throw QuoteWidgetStoreError.missingAppGroupContainer(appGroupIdentifier)
    }
    try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let databaseQueue = try DatabaseQueue(path: databaseURL.path)
    try databaseQueue.write { database in
      try createSchema(in: database)
      try database.execute(sql: "DELETE FROM quoteWidgetMetadata")
      try database.execute(
        sql: """
        INSERT INTO quoteWidgetMetadata (schemaVersion, sourceLibraryDisplayName, cacheTimestamp)
        VALUES (?, ?, ?)
        """,
        arguments: [QuoteWidgetDatabaseSchema.currentVersion, sourceLibraryDisplayName, cacheTimestamp]
      )
      try database.execute(sql: "DELETE FROM quoteWidgetCandidate")
      for (sortOrder, candidate) in candidates.enumerated() {
        try insert(candidate, sortOrder: sortOrder, into: database)
      }
    }
  }

  public func readCandidates(limit: Int) throws -> [QuoteWidgetCandidate] {
    guard limit > 0 else { return [] }
    guard let databaseURL else {
      throw QuoteWidgetStoreError.missingAppGroupContainer(appGroupIdentifier)
    }
    guard fileManager.fileExists(atPath: databaseURL.path) else {
      throw QuoteWidgetStoreError.missingDatabase(databaseURL)
    }
    let databaseQueue = try DatabaseQueue(path: databaseURL.path, configuration: readOnlyConfiguration)
    return try databaseQueue.read { database in
      let metadata = try Row.fetchOne(
        database,
        sql: "SELECT schemaVersion FROM quoteWidgetMetadata LIMIT 1"
      )
      guard let metadata else {
        throw QuoteWidgetStoreError.missingQuoteData
      }
      let schemaVersion: Int = metadata["schemaVersion"]
      guard schemaVersion == QuoteWidgetDatabaseSchema.currentVersion else {
        throw QuoteWidgetStoreError.unsupportedSchemaVersion(schemaVersion)
      }
      let rows = try Row.fetchAll(
        database,
        sql: """
        SELECT noteId, quoteKey, quoteText, attributionText, sourceTitle, thumbnailImage, selectedText, tags
        FROM quoteWidgetCandidate
        ORDER BY thumbnailImage IS NULL, sortOrder
        LIMIT ?
        """,
        arguments: [limit]
      )
      return try rows.map(QuoteWidgetCandidate.init(row:))
    }
  }

  public func writePreferredLibraryBookmark(for url: URL, displayName: String) throws {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      throw QuoteWidgetStoreError.missingAppGroupUserDefaults(appGroupIdentifier)
    }
    let bookmarkData = try url.bookmarkData()
    userDefaults.set(bookmarkData, forKey: Self.preferredLibraryBookmarkDataKey)
    userDefaults.set(displayName, forKey: Self.preferredLibraryDisplayNameKey)
  }

  public func preferredLibraryBookmarkData() throws -> Data {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      throw QuoteWidgetStoreError.missingAppGroupUserDefaults(appGroupIdentifier)
    }
    guard let bookmarkData = userDefaults.data(forKey: Self.preferredLibraryBookmarkDataKey) else {
      throw QuoteWidgetStoreError.missingPreferredLibraryBookmark
    }
    return bookmarkData
  }

  public func preferredLibraryDisplayName() throws -> String {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      throw QuoteWidgetStoreError.missingAppGroupUserDefaults(appGroupIdentifier)
    }
    guard let displayName = userDefaults.string(forKey: Self.preferredLibraryDisplayNameKey) else {
      throw QuoteWidgetStoreError.missingPreferredLibraryDisplayName
    }
    return displayName
  }

  private var containerURL: URL? {
    explicitContainerURL ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
  }

  private var readOnlyConfiguration: Configuration {
    var configuration = Configuration()
    configuration.readonly = true
    return configuration
  }

  private func createSchema(in database: Database) throws {
    try database.execute(sql: """
    CREATE TABLE IF NOT EXISTS quoteWidgetMetadata (
      schemaVersion INTEGER NOT NULL,
      sourceLibraryDisplayName TEXT NOT NULL,
      cacheTimestamp REAL NOT NULL
    )
    """)
    try database.execute(sql: """
    CREATE TABLE IF NOT EXISTS quoteWidgetCandidate (
      noteId TEXT NOT NULL,
      quoteKey TEXT NOT NULL,
      quoteText TEXT NOT NULL,
      attributionText TEXT NOT NULL,
      sourceTitle TEXT NOT NULL,
      thumbnailImage BLOB,
      selectedText TEXT NOT NULL,
      tags BLOB NOT NULL,
      sortOrder INTEGER NOT NULL,
      PRIMARY KEY (noteId, quoteKey)
    )
    """)
  }

  private func insert(_ candidate: QuoteWidgetCandidate, sortOrder: Int, into database: Database) throws {
    let tags = try JSONEncoder().encode(candidate.tags)
    let arguments: [(any DatabaseValueConvertible)?] = [
      candidate.noteId,
      candidate.quoteKey,
      candidate.quoteText,
      candidate.attributionText,
      candidate.sourceTitle,
      candidate.thumbnailImage,
      candidate.selectedText,
      tags,
      sortOrder,
    ]
    try database.execute(
      sql: """
      INSERT INTO quoteWidgetCandidate
      (noteId, quoteKey, quoteText, attributionText, sourceTitle, thumbnailImage, selectedText, tags, sortOrder)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      """,
      arguments: StatementArguments(arguments)
    )
  }
}

private enum QuoteWidgetDatabaseSchema {
  static let currentVersion = 1
}

private extension QuoteWidgetCandidate {
  init(row: Row) throws {
    let tagsData: Data = row["tags"]
    try self.init(
      noteId: row["noteId"],
      quoteKey: row["quoteKey"],
      quoteText: row["quoteText"],
      attributionText: row["attributionText"],
      sourceTitle: row["sourceTitle"],
      thumbnailImage: row["thumbnailImage"],
      selectedText: row["selectedText"],
      tags: JSONDecoder().decode([String].self, from: tagsData)
    )
  }
}

public enum QuoteWidgetStoreError: LocalizedError, Equatable {
  case missingAppGroupContainer(String)
  case missingAppGroupUserDefaults(String)
  case missingDatabase(URL)
  case missingQuoteData
  case missingPreferredLibraryBookmark
  case missingPreferredLibraryDisplayName
  case unsupportedSchemaVersion(Int)

  public var errorDescription: String? {
    switch self {
    case .missingAppGroupContainer(let identifier):
      "Could not find the app group container for \(identifier)."
    case .missingAppGroupUserDefaults(let identifier):
      "Could not open app group defaults for \(identifier)."
    case .missingDatabase(let url):
      "Could not find the quote widget database at \(url.path)."
    case .missingQuoteData:
      "The quote widget database does not contain any published quotes."
    case .missingPreferredLibraryBookmark:
      "No preferred library bookmark has been saved."
    case .missingPreferredLibraryDisplayName:
      "No preferred library display name has been saved."
    case .unsupportedSchemaVersion(let version):
      "Quote widget database schema version \(version) is not supported."
    }
  }
}
