// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import Foundation
import GRDB
import GRDBCombine
import MiniMarkdown

/// Implementation of the NoteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
public final class NoteSqliteStorage: NSObject {
  public init(fileURL: URL, parsingRules: ParsingRules) {
    self.fileURL = fileURL
    self.parsingRules = parsingRules
  }

  /// URL to the sqlite file
  public let fileURL: URL

  /// Parsing rules used to extract metadata from note contents.
  public let parsingRules: ParsingRules

  /// Connection to the in-memory database.
  private var dbQueue: DatabaseQueue?

  /// Set to `true` if there are unsaved changes in the in-memory database.
  private var hasUnsavedChanges = false

  /// Errors specific to this class.
  public enum Error: String, Swift.Error {
    case databaseAlreadyOpen = "The database is already open."
    case databaseIsNotOpen = "The database is not open."
    case noSuchNote = "The specified note does not exist."
  }

  /// Opens the database.
  /// - parameter completionHandler: A handler called after opening the database. If the error is nil, the database opened successfully.
  public func open(completionHandler: ((Swift.Error?) -> Void)? = nil) {
    guard dbQueue == nil else {
      completionHandler?(Error.databaseAlreadyOpen)
      return
    }
    do {
      let dbQueue = try memoryDatabaseQueue(fileURL: fileURL)
      hasUnsavedChanges = try runMigrations(on: dbQueue)
      self.dbQueue = dbQueue
      completionHandler?(nil)
    } catch {
      completionHandler?(error)
    }
  }

  /// Saves the database if there are any unsaved changes.
  /// - parameter completionHandler: A handler called after state is known to be saved. If the error is nil, everything happened successfully.
  public func saveIfNeeded(completionHandler: ((Swift.Error?) -> Void)? = nil) {
    guard let dbQueue = dbQueue, hasUnsavedChanges else {
      completionHandler?(nil)
      return
    }
    let coordinator = NSFileCoordinator(filePresenter: self)
    var coordinatorError: NSError?
    var innerError: Swift.Error?
    coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
      do {
        let fileQueue = try DatabaseQueue(path: coordinatedURL.path)
        try dbQueue.backup(to: fileQueue)
        hasUnsavedChanges = false
      } catch {
        innerError = error
      }
    }
    completionHandler?(coordinatorError ?? innerError)
  }

  /// Creates a new note.
  public func createNote(_ note: Note) throws -> Note.Identifier {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    let identifier = Note.Identifier()
    try dbQueue.write { db in
      let sqliteNote = Sqlite.Note(
        id: identifier.rawValue,
        title: note.metadata.title,
        modifiedTimestamp: note.metadata.timestamp,
        contents: note.text
      )
      _ = try JSONEncoder().encode(sqliteNote)
      try sqliteNote.insert(db)
    }
    return identifier
  }

  /// Gets a note with a specific identifier.
  public func note(noteIdentifier: Note.Identifier) throws -> Note {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db -> Note in
      guard let sqliteNote = try Sqlite.Note.fetchOne(db, key: noteIdentifier.rawValue) else {
        throw Error.noSuchNote
      }
      return Note(
        metadata: Note.Metadata(
          timestamp: sqliteNote.modifiedTimestamp,
          hashtags: [],
          title: sqliteNote.title,
          containsText: sqliteNote.contents != nil
        ),
        text: sqliteNote.contents,
        challengeTemplates: []
      )
    }
  }
}

// MARK: - Private

private extension NoteSqliteStorage {
  /// Creates an in-memory database queue for the contents of the file at `fileURL`
  /// - note: If fileURL does not exist, this method returns an empty database queue.
  /// - parameter fileURL: The file URL to read.
  /// - returns: An in-memory database queue with the contents of fileURL.
  func memoryDatabaseQueue(fileURL: URL) throws -> DatabaseQueue {
    let coordinator = NSFileCoordinator(filePresenter: self)
    var coordinatorError: NSError?
    var result: Result<DatabaseQueue, Swift.Error>?
    coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
      result = Result {
        let queue = try DatabaseQueue(path: ":memory:")
        if let fileQueue = try? DatabaseQueue(path: coordinatedURL.path) {
          try fileQueue.backup(to: queue)
        }
        return queue
      }
    }

    if let coordinatorError = coordinatorError {
      throw coordinatorError
    }

    switch result {
    case .failure(let error):
      throw error
    case .success(let dbQueue):
      return dbQueue
    case .none:
      preconditionFailure()
    }
  }

  /// Makes sure the database is up-to-date.
  /// - returns: true if migrations ran.
  func runMigrations(on databaseQueue: DatabaseQueue) throws -> Bool {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("initialSchema") { database in
      try database.create(table: "note", body: { table in
        table.column("id", .text).primaryKey()
        table.column("title", .text).notNull().defaults(to: "")
        table.column("modifiedTimestamp", .datetime).notNull()
        table.column("contents", .text)
      })

      try database.create(table: "hashtag", body: { table in
        table.column("id", .text).primaryKey()
      })

      try database.create(table: "noteHashtag", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("noteId", .text)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
        table.column("hashtagId", .text)
          .notNull()
          .indexed()
          .references("hashtag", onDelete: .cascade)
      })

      try database.create(table: "challengeTemplate", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("type", .text).notNull()
        table.column("rawValue", .text).notNull()
        table.column("noteId", .text)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
      })

      try database.create(table: "challenge", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("due", .datetime)
        table.column("challengeTemplateId", .integer)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
      })

      try database.create(table: "studyLogEntry", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("timestamp", .datetime).notNull()
        table.column("correct", .integer).notNull().defaults(to: 0)
        table.column("incorrect", .integer).notNull().defaults(to: 0)
        table.column("challengeId", .integer)
          .notNull()
          .references("challenge", onDelete: .cascade)
      })
    }

    let existingMigratinos = try migrator.appliedMigrations(in: databaseQueue)
    if !existingMigratinos.contains("initialSchema") {
      try migrator.migrate(databaseQueue)
      return true
    }
    return false
  }
}

// MARK: - NSFilePresenter

extension NoteSqliteStorage: NSFilePresenter {
  public var presentedItemURL: URL? { fileURL }
  public var presentedItemOperationQueue: OperationQueue { OperationQueue.main }
}
