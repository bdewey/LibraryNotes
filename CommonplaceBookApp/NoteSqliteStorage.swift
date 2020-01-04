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
    case unknownChallengeType = "The challenge template uses an unknown type."
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
      try writeNote(note, with: identifier, to: db, createNew: true)
    }
    return identifier
  }

  /// Updates a note.
  /// - parameter noteIdentifier: The identifier of the note to update.
  /// - parameter updateBlock: A block that receives the current value of the note and returns the updated value.
  public func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    try dbQueue.write { db in
      let existingNote = try loadNote(with: noteIdentifier, from: db)
      let updatedNote = updateBlock(existingNote)
      try writeNote(updatedNote, with: noteIdentifier, to: db, createNew: false)
    }
  }

  /// Gets a note with a specific identifier.
  public func note(noteIdentifier: Note.Identifier) throws -> Note {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db -> Note in
      return try loadNote(with: noteIdentifier, from: db)
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

  func writeNote(_ note: Note, with identifier: Note.Identifier, to db: Database, createNew: Bool) throws {
    let sqliteNote = Sqlite.Note(
      id: identifier.rawValue,
      title: note.metadata.title,
      modifiedTimestamp: note.metadata.timestamp,
      contents: note.text
    )
    if createNew {
      try sqliteNote.insert(db)
    } else {
      try sqliteNote.update(db)
    }
    let inMemoryHashtags = Set(note.metadata.hashtags)
    let onDiskHashtags = ((try? sqliteNote.hashtags.fetchAll(db)) ?? [])
      .map { $0.id }
      .asSet()
    for newHashtag in inMemoryHashtags.subtracting(onDiskHashtags) {
      _ = try fetchOrCreateHashtag(newHashtag, in: db)
      let associationRecord = Sqlite.NoteHashtag(noteId: identifier.rawValue, hashtagId: newHashtag)
      try associationRecord.save(db)
    }
    for obsoleteHashtag in onDiskHashtags.subtracting(inMemoryHashtags) {
      let deleted = try Sqlite.NoteHashtag.deleteOne(db, key: ["noteId": identifier.rawValue, "hashtagId": obsoleteHashtag])
      assert(deleted)
    }

    for template in note.challengeTemplates where template.templateIdentifier == nil {
      template.templateIdentifier = UUID().uuidString
    }
    let inMemoryChallengeTemplates = Set(note.challengeTemplates.map({ $0.templateIdentifier! }))
    let onDiskChallengeTemplates = ((try? sqliteNote.challengeTemplates.fetchAll(db)) ?? [])
      .map { $0.id }
      .asSet()

    let encoder = JSONEncoder()
    for newTemplateIdentifier in inMemoryChallengeTemplates.subtracting(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == newTemplateIdentifier })!
      let templateData = try encoder.encode(template)
      let templateString = String(data: templateData, encoding: .utf8)!
      let record = Sqlite.ChallengeTemplate(
        id: newTemplateIdentifier,
        type: template.type.rawValue,
        rawValue: templateString,
        noteId: identifier.rawValue
      )
      try record.insert(db)
    }
    for obsoleteTemplateIdentifier in onDiskChallengeTemplates.subtracting(inMemoryChallengeTemplates) {
      let deleted = try Sqlite.ChallengeTemplate.deleteOne(db, key: obsoleteTemplateIdentifier)
      assert(deleted)
    }
  }

  func fetchOrCreateHashtag(_ hashtag: String, in db: Database) throws -> Sqlite.Hashtag {
    if let existing = try Sqlite.Hashtag.fetchOne(db, key: hashtag) {
      return existing
    }
    let newRecord = Sqlite.Hashtag(id: hashtag)
    try newRecord.insert(db)
    return newRecord
  }

  func loadNote(with identifier: Note.Identifier, from db: Database) throws -> Note {
    guard let sqliteNote = try Sqlite.Note.fetchOne(db, key: identifier.rawValue) else {
      throw Error.noSuchNote
    }
    let hashtagRecords = try Sqlite.NoteHashtag.filter(Sqlite.NoteHashtag.Columns.noteId == identifier.rawValue).fetchAll(db)
    let hashtags = hashtagRecords.map { $0.hashtagId }
    let challengeTemplateRecords = try Sqlite.ChallengeTemplate
      .filter(Sqlite.ChallengeTemplate.Columns.noteId == identifier.rawValue)
      .fetchAll(db)
    let decoder = JSONDecoder()
    decoder.userInfo = [.markdownParsingRules: parsingRules]
    let challengeTemplates = try challengeTemplateRecords.map { challengeTemplateRecord -> ChallengeTemplate in
      guard let klass = ChallengeTemplateType.classMap[challengeTemplateRecord.type] else {
        throw Error.unknownChallengeType
      }
      let templateData = challengeTemplateRecord.rawValue.data(using: .utf8)!
      let template = try decoder.decode(klass, from: templateData)
      template.templateIdentifier = challengeTemplateRecord.id
      return template
    }
    return Note(
      metadata: Note.Metadata(
        timestamp: sqliteNote.modifiedTimestamp,
        hashtags: hashtags,
        title: sqliteNote.title,
        containsText: sqliteNote.contents != nil
      ),
      text: sqliteNote.contents,
      challengeTemplates: challengeTemplates
    )
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
        table.column("noteId", .text)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
        table.column("hashtagId", .text)
          .notNull()
          .indexed()
          .references("hashtag", onDelete: .cascade)
        table.primaryKey(["noteId", "hashtagId"])
      })

      try database.create(table: "challengeTemplate", body: { table in
        table.column("id", .text).primaryKey()
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

private extension Sequence where Element: Hashable {
  /// Converts the receiver into a set.
  func asSet() -> Set<Element> { Set(self) }
}
