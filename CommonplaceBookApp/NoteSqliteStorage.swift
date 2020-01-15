// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import Foundation
import GRDB
import GRDBCombine
import MiniMarkdown
import Yams

private var hackDecodeCount = 0

/// Implementation of the NoteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
public final class NoteSqliteStorage: NSObject, NoteStorage {
  public init(fileURL: URL, parsingRules: ParsingRules, autosaveTimeInterval: TimeInterval = 10) {
    self.fileURL = fileURL
    self.parsingRules = parsingRules
    self.autosaveTimeInterval = autosaveTimeInterval
    self.notesDidChange = notesDidChangeSubject.eraseToAnyPublisher()
    self.didAutosave = autosaveSubject.eraseToAnyPublisher()
  }

  deinit {
    autosaveTimer = nil
    try? flush()
  }

  /// URL to the sqlite file
  public let fileURL: URL

  /// Parsing rules used to extract metadata from note contents.
  public let parsingRules: ParsingRules

  /// Connection to the in-memory database.
  private var dbQueue: DatabaseQueue?

  /// Set to `true` if there are unsaved changes in the in-memory database.
  public private(set) var hasUnsavedChanges = false

  /// Set to false to temporarily disable writing
  private var isWriteable = true

  /// Pipeline monitoring for changes in the database.
  private var metadataUpdatePipeline: AnyCancellable?

  /// Pipeline for monitoring for unsaved changes to the in-memory database.
  private var hasUnsavedChangesPipeline: AnyCancellable?

  /// How long to wait before autosaving.
  private let autosaveTimeInterval: TimeInterval

  /// Used for decoding challenge templates.
  private lazy var decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.userInfo = [.markdownParsingRules: parsingRules]
    return decoder
  }()

  /// The actual autosave timer.
  private var autosaveTimer: Timer? {
    willSet {
      autosaveTimer?.invalidate()
    }
  }

  /// Private publisher to let outside observers know autosave happened.
  private let autosaveSubject = PassthroughSubject<Void, Never>()

  /// Notification when autosave happens.
  public let didAutosave: AnyPublisher<Void, Never>

  /// Errors specific to this class.
  public enum Error: String, Swift.Error {
    case cannotDecodeTemplate = "Cannot decode challenge template."
    case databaseAlreadyOpen = "The database is already open."
    case databaseIsNotOpen = "The database is not open."
    case noSuchAsset = "The specified asset does not exist."
    case noSuchNote = "The specified note does not exist."
    case notWriteable = "The database is not currently writeable."
    case unknownChallengeTemplate = "The challenge template does not exist."
    case unknownChallengeType = "The challenge template uses an unknown type."
  }

  /// Opens the database.
  /// - parameter completionHandler: A handler called after opening the database. If the error is nil, the database opened successfully.
  public func open(completionHandler: ((Bool) -> Void)?) {
    do {
      try open()
      completionHandler?(true)
    } catch {
      DDLogError("Unexpected error opening database: \(error)")
      completionHandler?(false)
    }
  }

  /// Synchronous `open` variant.
  public func open() throws {
    guard dbQueue == nil else {
      throw Error.databaseAlreadyOpen
    }
    let dbQueue = try memoryDatabaseQueue(fileURL: fileURL)
    hasUnsavedChanges = try runMigrations(on: dbQueue)
    self.dbQueue = dbQueue
    allMetadata = try dbQueue.read { db in
      try Self.fetchAllMetadata(from: db)
    }
    metadataUpdatePipeline = DatabaseRegionObservation(tracking: [
      Sqlite.Note.all(),
    ]).publisher(in: dbQueue)
      .tryMap { db in try Self.fetchAllMetadata(from: db) }
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            DDLogError("Unexpected error monitoring database: \(error)")
          case .finished:
            DDLogInfo("Monitoring pipeline shutting down")
          }
        },
        receiveValue: { [weak self] allMetadata in
          self?.allMetadata = allMetadata
        }
      )
    hasUnsavedChangesPipeline = DatabaseRegionObservation(tracking: [
      Sqlite.Note.all(),
      Sqlite.NoteText.all(),
      Sqlite.NoteHashtag.all(),
      Sqlite.StudyLogEntry.all(),
      Sqlite.Asset.all(),
    ]).publisher(in: dbQueue)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            DDLogError("Unexpected error monitoring database: \(error)")
          case .finished:
            DDLogInfo("hasUnsavedChanges shutting down")
          }
        },
        receiveValue: { [weak self] _ in
          self?.hasUnsavedChanges = true
        }
      )
    autosaveTimer = Timer.scheduledTimer(
      withTimeInterval: autosaveTimeInterval, repeats: true, block: { [weak self] _ in
        do {
          try self?.flush()
          self?.autosaveSubject.send()
        } catch {
          DDLogInfo("Error autosaving: \(error)")
        }
      }
    )
  }

  /// Ensures contents are saved to stable storage.
  public func flush() throws {
    guard let dbQueue = dbQueue, hasUnsavedChanges else {
      return
    }
    guard isWriteable else {
      throw Error.notWriteable
    }
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("notedb")
    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }
    try dbQueue.writeWithoutTransaction { db in
      try db.execute(sql: "VACUUM INTO '\(tempURL.path)'")
    }
    let coordinator = NSFileCoordinator(filePresenter: self)
    var coordinatorError: NSError?
    var innerError: Swift.Error?
    coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
      do {
        let didGetAccess = coordinatedURL.startAccessingSecurityScopedResource()
        defer {
          if didGetAccess {
            coordinatedURL.stopAccessingSecurityScopedResource()
          }
        }
        let newURL = try FileManager.default.replaceItemAt(coordinatedURL, withItemAt: tempURL)
        assert(newURL == coordinatedURL)
        hasUnsavedChanges = false
      } catch {
        innerError = error
      }
    }
    if let coordinatorError = coordinatorError {
      throw coordinatorError
    }
    if let innerError = innerError {
      throw innerError
    }
  }

  public var allMetadata: [Note.Identifier: Note.Metadata] = [:] {
    willSet {
      assert(Thread.isMainThread)
    }
    didSet {
      notesDidChangeSubject.send()
    }
  }

  public let notesDidChange: AnyPublisher<Void, Never>
  private let notesDidChangeSubject = PassthroughSubject<Void, Never>()

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

  public func search(for searchPattern: String) throws -> [Note.Identifier] {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      if !searchPattern.trimmingCharacters(in: .whitespaces).isEmpty {
        let pattern = try db.makeFTS5Pattern(rawPattern: searchPattern.trimmingCharacters(in: .whitespaces).appending("*"), forTable: "noteFullText")
        let sql = """
        SELECT noteText.*
        FROM noteText
        JOIN noteFullText
          ON noteFullText.rowid = noteText.rowid
          AND noteFullText MATCH ?
        """
        let noteTexts = try Sqlite.NoteText.fetchAll(db, sql: sql, arguments: [pattern])
        return noteTexts.map { Note.Identifier(rawValue: $0.noteId) }
      } else {
        let noteTexts = try Sqlite.NoteText.fetchAll(db)
        return noteTexts.map { Note.Identifier(rawValue: $0.noteId) }
      }
    }
  }

  /// Gets a note with a specific identifier.
  public func note(noteIdentifier: Note.Identifier) throws -> Note {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db -> Note in
      try loadNote(with: noteIdentifier, from: db)
    }
  }

  public func deleteNote(noteIdentifier: Note.Identifier) throws {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    _ = try dbQueue.write { db in
      try Sqlite.Note.deleteOne(db, key: noteIdentifier.rawValue)
    }
  }

  public func eligibleChallengeIdentifiers(
    before date: Date,
    limitedTo noteIdentifier: Note.Identifier?
  ) throws -> [ChallengeIdentifier] {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      let challengeRequest: QueryInterfaceRequest<Sqlite.Challenge>
      if let noteIdentifier = noteIdentifier {
        guard let note = try Sqlite.Note.fetchOne(db, key: noteIdentifier.rawValue) else {
          throw Error.noSuchNote
        }
        challengeRequest = note.challenges
      } else {
        challengeRequest = Sqlite.Challenge.all()
      }
      let records = try challengeRequest
        .filter(Sqlite.Challenge.Columns.due == nil || Sqlite.Challenge.Columns.due <= date)
        .fetchAll(db)
      return records.map {
        ChallengeIdentifier(templateDigest: $0.challengeTemplateId, index: $0.index)
      }
    }
  }

  public func challenge(
    noteIdentifier: Note.Identifier,
    challengeIdentifier: ChallengeIdentifier
  ) throws -> Challenge {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    guard let templateIdentifier = challengeIdentifier.templateDigest else {
      throw Error.unknownChallengeTemplate
    }
    return try dbQueue.read { db in
      let template = try challengeTemplate(identifier: templateIdentifier, database: db)
      return template.challenges[challengeIdentifier.index]
    }
  }

  internal func countOfTextRows() throws -> Int {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      try Sqlite.NoteText.fetchCount(db)
    }
  }

  public var assetKeys: [String] {
    do {
      guard let dbQueue = dbQueue else {
        throw Error.databaseIsNotOpen
      }
      return try dbQueue.read { db in
        let request = Sqlite.Asset.select([Sqlite.Asset.Columns.id])
        return try String.fetchAll(db, request)
      }
    } catch {
      DDLogError("Unexpected error getting asset keys: \(error)")
      return []
    }
  }

  public func data<S>(for fileWrapperKey: S) throws -> Data? where S: StringProtocol {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      guard let asset = try Sqlite.Asset.fetchOne(db, key: String(fileWrapperKey)) else {
        throw Error.noSuchAsset
      }
      return asset.data
    }
  }

  public func storeAssetData(_ data: Data, key: String) throws -> String {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.write { db in
      let asset = Sqlite.Asset(id: key, data: data)
      try asset.save(db)
      return key
    }
  }

  public func recordStudyEntry(_ entry: StudyLog.Entry) throws {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    try dbQueue.write { db in
      guard
        let templateKey = entry.identifier.templateDigest,
        let owningTemplate = try Sqlite.ChallengeTemplate.fetchOne(db, key: templateKey),
        var challenge = try owningTemplate.challenges.filter(Sqlite.Challenge.Columns.index == entry.identifier.index).fetchOne(db)
      else {
        throw Error.unknownChallengeTemplate
      }

      var record = Sqlite.StudyLogEntry(
        id: nil,
        timestamp: entry.timestamp,
        correct: entry.statistics.correct,
        incorrect: entry.statistics.incorrect,
        challengeId: challenge.id!
      )
      try record.insert(db)

      challenge.reviewCount += 1
      challenge.totalCorrect += entry.statistics.correct
      challenge.totalIncorrect += entry.statistics.incorrect

      if let lastReview = challenge.lastReview {
        // The minimum delta is 1 day
        let delta = Swift.max(entry.timestamp.timeIntervalSince(lastReview), TimeInterval.day)
        let factor = pow(2.0, 1.0 - Double(entry.statistics.incorrect))
        let nextDate = entry.timestamp.addingTimeInterval(delta * factor)
        challenge.lastReview = entry.timestamp
        challenge.due = nextDate
      } else {
        challenge.lastReview = entry.timestamp
        challenge.due = entry.timestamp.addingTimeInterval(TimeInterval.day)
      }
      try challenge.update(db)
    }
    notesDidChangeSubject.send()
  }

  public var studyLog: StudyLog {
    var log = StudyLog()
    do {
      guard let dbQueue = dbQueue else {
        throw Error.databaseIsNotOpen
      }
      let entries = try dbQueue.read { db -> [Sqlite.StudyLogEntryInfo] in
        let request = Sqlite.StudyLogEntry
          .order(Sqlite.StudyLogEntry.Columns.timestamp)
          .including(required: Sqlite.StudyLogEntry.challenge)
        return try Sqlite.StudyLogEntryInfo
          .fetchAll(db, request)
      }
      entries
        .map {
          StudyLog.Entry(
            timestamp: $0.studyLogEntry.timestamp,
            identifier: ChallengeIdentifier(
              templateDigest: $0.challenge.challengeTemplateId,
              index: $0.challenge.index
            ),
            statistics: AnswerStatistics(
              correct: $0.studyLogEntry.correct,
              incorrect: $0.studyLogEntry.incorrect
            )
          )
        }
        .forEach { log.append($0) }
      return log
    } catch {
      DDLogError("Unexpected error fetching study log: \(error)")
    }
    return log
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
        do {
          let didGetAccess = coordinatedURL.startAccessingSecurityScopedResource()
          defer {
            if didGetAccess {
              coordinatedURL.stopAccessingSecurityScopedResource()
            }
          }
          let fileQueue = try DatabaseQueue(path: coordinatedURL.path)
          try fileQueue.backup(to: queue)
        } catch {
          DDLogInfo("Unable to load \(coordinatedURL.path): \(error)")
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

  @discardableResult
  func writeNoteText(_ noteText: String?, with identifier: Note.Identifier, to db: Database) throws -> Int64? {
    guard let noteText = noteText else {
      return nil
    }
    if var existingRecord = try Sqlite.NoteText.fetchOne(db, key: ["noteId": identifier.rawValue]) {
      existingRecord.text = noteText
      try existingRecord.update(db)
      return existingRecord.id
    } else {
      var newRecord = Sqlite.NoteText(id: nil, text: noteText, noteId: identifier.rawValue)
      try newRecord.insert(db)
      return newRecord.id
    }
  }

  func writeNote(_ note: Note, with identifier: Note.Identifier, to db: Database, createNew: Bool) throws {
    let sqliteNote = Sqlite.Note(
      id: identifier.rawValue,
      title: note.metadata.title,
      modifiedTimestamp: note.metadata.timestamp,
      hasText: note.text != nil
    )
    if createNew {
      try sqliteNote.insert(db)
    } else {
      try sqliteNote.update(db)
    }
    try writeNoteText(note.text, with: identifier, to: db)
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
    let inMemoryChallengeTemplates = Set(note.challengeTemplates.map { $0.templateIdentifier! })
    let onDiskChallengeTemplates = ((try? sqliteNote.challengeTemplates.fetchAll(db)) ?? [])
      .map { $0.id }
      .asSet()

    for newTemplateIdentifier in inMemoryChallengeTemplates.subtracting(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == newTemplateIdentifier })!
      let templateString = template.rawValue
      let record = Sqlite.ChallengeTemplate(
        id: newTemplateIdentifier,
        type: template.type.rawValue,
        rawValue: templateString,
        noteId: identifier.rawValue
      )
      try record.insert(db)
      for index in template.challenges.indices {
        var challengeRecord = Sqlite.Challenge(index: index, challengeTemplateId: newTemplateIdentifier)
        try challengeRecord.insert(db)
      }
    }
    for modifiedTemplateIdentifier in inMemoryChallengeTemplates.intersection(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == modifiedTemplateIdentifier })!
      guard var record = try Sqlite.ChallengeTemplate.fetchOne(db, key: modifiedTemplateIdentifier) else {
        assertionFailure("Should be a record")
        continue
      }
      record.rawValue = template.rawValue
      try record.update(db, columns: [Sqlite.ChallengeTemplate.Columns.rawValue])
    }
    for obsoleteTemplateIdentifier in onDiskChallengeTemplates.subtracting(inMemoryChallengeTemplates) {
      let deleted = try Sqlite.ChallengeTemplate.deleteOne(db, key: obsoleteTemplateIdentifier)
      assert(deleted)
    }
  }

  static func fetchAllMetadata(from db: Database) throws -> [Note.Identifier: Note.Metadata] {
    let metadata = try Sqlite.NoteMetadata.fetchAll(db, Sqlite.NoteMetadata.request)
    let tuples = metadata.map { metadataItem -> (key: Note.Identifier, value: Note.Metadata) in
      let metadata = Note.Metadata(
        timestamp: metadataItem.modifiedTimestamp,
        hashtags: metadataItem.hashtags.map { $0.id },
        title: metadataItem.title,
        containsText: metadataItem.hasText
      )
      let noteIdentifier = Note.Identifier(rawValue: metadataItem.id)
      return (key: noteIdentifier, value: metadata)
    }
    return Dictionary(uniqueKeysWithValues: tuples)
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
    let challengeTemplates = try challengeTemplateRecords.map { challengeTemplateRecord -> ChallengeTemplate in
      try challengeTemplate(from: challengeTemplateRecord)
    }
    let noteText = try Sqlite.NoteText.fetchOne(db, key: ["noteId": identifier.rawValue])?.text
    return Note(
      metadata: Note.Metadata(
        timestamp: sqliteNote.modifiedTimestamp,
        hashtags: hashtags,
        title: sqliteNote.title,
        containsText: sqliteNote.hasText
      ),
      text: noteText,
      challengeTemplates: challengeTemplates
    )
  }

  func challengeTemplate(identifier: String, database: Database) throws -> ChallengeTemplate {
    guard let record = try Sqlite.ChallengeTemplate.fetchOne(database, key: identifier) else {
      throw Error.unknownChallengeTemplate
    }
    return try challengeTemplate(from: record)
  }

  func challengeTemplate(
    from challengeTemplateRecord: Sqlite.ChallengeTemplate
  ) throws -> ChallengeTemplate {
    guard let klass = ChallengeTemplateType.classMap[challengeTemplateRecord.type] else {
      throw Error.unknownChallengeType
    }
    let rawValue = (try? YAMLDecoder().decode(String.self, from: challengeTemplateRecord.rawValue, userInfo: [:])) ?? challengeTemplateRecord.rawValue
    guard let template = klass.init(rawValue: rawValue) else {
      throw Error.cannotDecodeTemplate
    }
    template.templateIdentifier = challengeTemplateRecord.id
    hackDecodeCount += 1
    if hackDecodeCount % 20 == 0 {
      print("Decoded \(hackDecodeCount) templates")
    }
    return template
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
        table.column("hasText", .boolean).notNull()
      })

      try database.create(table: "noteText", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("text", .text).notNull()
        table.column("noteId", .text).notNull().indexed().unique().references("note", onDelete: .cascade)
      })

      try database.create(virtualTable: "noteFullText", using: FTS5()) { table in
        table.synchronize(withTable: "noteText")
        table.column("text")
        table.tokenizer = .porter(wrapping: .unicode61())
      }

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
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("challengeTemplateId", .text)
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

      try database.create(table: "asset", body: { table in
        table.column("id", .text).primaryKey()
        table.column("data", .blob).notNull()
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

  public func savePresentedItemChanges(completionHandler: @escaping (Swift.Error?) -> Void) {
    DDLogInfo("NSFilePresenter savePresentedItemChanges")
    do {
      try flush()
      completionHandler(nil)
    } catch {
      completionHandler(error)
    }
  }

  public func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
    DDLogInfo("NSFilePresenter relinquishing to a reader")
    isWriteable = false
    reader {
      DDLogInfo("NSFilePresenter writeable again")
      self.isWriteable = true
    }
  }

  public func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
    DDLogInfo("NSFilePresenter relinquishing to a writer")
    isWriteable = false
    writer {
      DDLogInfo("NSFilePresenter writeable again")
      self.isWriteable = true
    }
  }

  public func presentedItemDidChange() {
    DDLogInfo("NSFilePresenter reopening file")
    dbQueue = nil
    do {
      try open()
    } catch {
      DDLogError("Unexpected error re-opening database after external change: \(error)")
    }
  }
}
