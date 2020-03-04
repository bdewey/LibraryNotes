// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import Foundation
import GRDB
import GRDBCombine
import MiniMarkdown
import SpacedRepetitionScheduler
import Yams

// swiftlint:disable file_length

/// Used to identify the device that authors changes.
public protocol DeviceIdentifying {
  /// A UUID uniquely identifying this device.
  var identifierForVendor: UUID? { get }

  /// A human-readable name for this device.
  var name: String { get }
}

/// UIDevice conforms to DeviceIdentifying.
extension UIDevice: DeviceIdentifying {}

/// Implementation of the NoteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
public final class NoteSqliteStorage: UIDocument, NoteStorage {
  /// Designated initializer.
  public init(
    fileURL: URL,
    parsingRules: ParsingRules,
    device: DeviceIdentifying = UIDevice.current
  ) {
    self.parsingRules = parsingRules
    self.device = device
    self.notesDidChange = notesDidChangeSubject.eraseToAnyPublisher()
    super.init(fileURL: fileURL)
  }

  /// Parsing rules used to extract metadata from note contents.
  public let parsingRules: ParsingRules

  /// The device that this instance runs on.
  public let device: DeviceIdentifying

  /// The device record associated with this open database on this device. Valid when there is an open database.
  private var deviceRecord: Sqlite.Device!

  /// Our scheduler.
  public static let scheduler: SpacedRepetitionScheduler = {
    SpacedRepetitionScheduler(
      learningIntervals: [.day, 4 * .day],
      goodGraduatingInterval: 7 * .day
    )
  }()

  /// Used for generating IDs. Will get created when the database is opened. Only access on the database queue.
  private var flakeMaker: FlakeMaker!

  public func makeIdentifier() -> FlakeID {
    flakeMaker.nextValue()
  }

  /// Connection to the in-memory database.
  private var dbQueue: DatabaseQueue? {
    didSet {
      if let queue = dbQueue {
        do {
          try monitorDatabaseQueue(queue)
        } catch {
          DDLogError("Unexpected error monitoring queue for changes: \(error)")
        }
      }
    }
  }

  /// Pipeline monitoring for changes in the database.
  private var metadataUpdatePipeline: AnyCancellable?

  /// Pipeline for monitoring for unsaved changes to the in-memory database.
  private var hasUnsavedChangesPipeline: AnyCancellable?

  /// Used for decoding challenge templates.
  private lazy var decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.userInfo = [.markdownParsingRules: parsingRules]
    return decoder
  }()

  /// Errors specific to this class.
  public enum Error: String, Swift.Error {
    case cannotDecodeTemplate = "Cannot decode challenge template."
    case databaseAlreadyOpen = "The database is already open."
    case databaseIsNotOpen = "The database is not open."
    case noDeviceUUID = "Could note get the device UUID."
    case noSuchAsset = "The specified asset does not exist."
    case noSuchChallenge = "The specified challenge does not exist."
    case noSuchNote = "The specified note does not exist."
    case notWriteable = "The database is not currently writeable."
    case unknownChallengeTemplate = "The challenge template does not exist."
    case unknownChallengeType = "The challenge template uses an unknown type."
  }

  public override func open(completionHandler: ((Bool) -> Void)? = nil) {
    super.open { success in
      DDLogInfo("UIDocument: Opened '\(self.fileURL.path)' -- success = \(success) state = \(self.documentState)")
      NotificationCenter.default.addObserver(self, selector: #selector(self.handleDocumentStateChanged), name: UIDocument.stateChangedNotification, object: self)
      self.handleDocumentStateChanged()
      completionHandler?(success)
    }
  }

  public override func close(completionHandler: ((Bool) -> Void)? = nil) {
    NotificationCenter.default.removeObserver(self)
    super.close(completionHandler: completionHandler)
  }

  /// Merges new content from another storage container into this storage container.
  public func merge(other: NoteSqliteStorage) throws -> MergeResult {
    guard let localQueue = dbQueue, let remoteQueue = other.dbQueue else {
      throw Error.databaseIsNotOpen
    }
    let result = try localQueue.merge(remoteQueue: remoteQueue)
    if !result.isEmpty {
      notesDidChangeSubject.send()
    }
    return result
  }

  @objc private func handleDocumentStateChanged() {
    guard documentState.contains(.inConflict) else {
      return
    }
    DDLogInfo("UIDocument: Handling conflict")
    do {
      var conflictMergeResults = MergeResult()
      for conflictVersion in NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? [] {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("notedb")
        try conflictVersion.replaceItem(at: tempURL, options: [])
        defer {
          try? FileManager.default.removeItem(at: tempURL)
        }
        let conflictQueue = try memoryDatabaseQueue(fileURL: tempURL)
        if let dbQueue = dbQueue {
          let result = try dbQueue.merge(remoteQueue: conflictQueue)
          DDLogInfo("UIDocument: Merged conflict version: \(result)")
          conflictMergeResults += result
        } else {
          DDLogInfo("UIDocument: Trying to resolve conflict but dbQueue is nil?")
          dbQueue = conflictQueue
        }
        conflictVersion.isResolved = true
        try conflictVersion.remove()
      }
      DDLogInfo("UIDocument: Finished resolving conflicts")
      try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
      if !conflictMergeResults.isEmpty {
        notesDidChangeSubject.send()
      }
    } catch {
      DDLogError("UIDocument: Unexpected error resolving conflict: \(error)")
    }
  }

  public override func read(from url: URL) throws {
    // TODO: Optionally merge the changes from disk into memory?
    DDLogInfo("UIDocument: Reading content from '\(url.path)'")
    let dbQueue = try memoryDatabaseQueue(fileURL: url)
    DispatchQueue.main.async {
      if let inMemoryQueue = self.dbQueue {
        if dbQueue.deviceVersionVector == inMemoryQueue.deviceVersionVector {
          DDLogInfo("UIDocument: On-disk content is the same as memory; ignoring")
        } else if dbQueue.deviceVersionVector > inMemoryQueue.deviceVersionVector {
          DDLogInfo("UIDocument: On-disk data is strictly greater than in-memory; overwriting")
          self.dbQueue = dbQueue
        } else {
          DDLogInfo("UIDocument: **Merging** disk contents with memory.\nDisk: \(dbQueue.deviceVersionVector)\nMemory: \(inMemoryQueue.deviceVersionVector)")
          do {
            let result = try inMemoryQueue.merge(remoteQueue: dbQueue)
            DDLogInfo("UIDocument: Merged disk results \(result)")
            if !result.isEmpty {
              self.notesDidChangeSubject.send()
            }
          } catch {
            DDLogError("UIDocument: Could not merge disk contents! \(error)")
          }
        }
      } else {
        DDLogInfo("UIDocument: Nothing in memory, using the disk image")
        self.dbQueue = dbQueue
      }
    }
  }

  public override func writeContents(
    _ contents: Any,
    to url: URL,
    for saveOperation: UIDocument.SaveOperation,
    originalContentsURL: URL?
  ) throws {
    guard let dbQueue = dbQueue else {
      return
    }
    DDLogInfo("UIDocument: Writing content to '\(url.path)'")
    try dbQueue.writeWithoutTransaction { db in
      try db.execute(sql: "VACUUM INTO '\(url.path)'")
    }
  }

  public func flush() throws {
    save(to: fileURL, for: .forOverwriting, completionHandler: nil)
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
    let identifier = flakeMaker.nextValue()
    try dbQueue.write { db in
      try writeNote(note, with: identifier, to: db)
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
      try writeNote(updatedNote, with: noteIdentifier, to: db)
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
        return noteTexts.map { $0.noteId }
      } else {
        let noteTexts = try Sqlite.NoteText.fetchAll(db)
        return noteTexts.map { $0.noteId }
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
      guard var note = try Sqlite.Note.filter(key: noteIdentifier.rawValue).fetchOne(db) else {
        return
      }
      var device = try currentDeviceRecord(in: db)
      try note.noteText.deleteAll(db)
      try note.challengeTemplates.deleteAll(db)
      note.deleted = true
      note.modifiedDevice = device.id!
      note.modifiedTimestamp = Date()
      device.latestChange = max(device.latestChange, note.modifiedTimestamp)
      try device.update(db)
      try note.update(db)
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
        ChallengeIdentifier(templateDigest: FlakeID(rawValue: $0.challengeTemplateId), index: $0.index)
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
    guard let templateIdentifier = challengeIdentifier.challengeTemplateID else {
      throw Error.unknownChallengeTemplate
    }
    return try dbQueue.read { db in
      let template = try Self.challengeTemplate(identifier: templateIdentifier, database: db)
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

  public func recordStudyEntry(_ entry: StudyLog.Entry, buryRelatedChallenges: Bool) throws {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    try dbQueue.write { db in
      guard
        let templateKey = entry.identifier.challengeTemplateID,
        let owningTemplate = try Sqlite.ChallengeTemplate.fetchOne(db, key: templateKey.rawValue),
        let challenge = try owningTemplate.challenges.filter(Sqlite.Challenge.Columns.index == entry.identifier.index).fetchOne(db)
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
      let deviceID = Int64(flakeMaker.instanceNumber)
      try Self.updateChallenge(for: record, in: db, buryRelatedChallenges: buryRelatedChallenges, deviceID: deviceID)
    }
    notesDidChangeSubject.send()
  }

  private static func updateChallenge(
    for entry: Sqlite.StudyLogEntry,
    in db: Database,
    buryRelatedChallenges: Bool,
    deviceID: Int64
  ) throws {
    var challenge = try Sqlite.Challenge.fetchOne(db, key: entry.challengeId)!
    var device = try Sqlite.Device.fetchOne(db, key: deviceID)!
    let delay: TimeInterval
    if let lastReview = challenge.lastReview, let idealInterval = challenge.idealInterval {
      let idealDate = lastReview.addingTimeInterval(idealInterval)
      delay = max(entry.timestamp.timeIntervalSince(idealDate), 0)
    } else {
      delay = 0
    }
    let schedulingOptions = Self.scheduler.scheduleItem(challenge.item, afterDelay: delay)
    let outcome = schedulingOptions[entry.cardAnswer] ?? schedulingOptions[.again]!

    challenge.applyItem(outcome, on: entry.timestamp, from: deviceID)
    challenge.totalCorrect += entry.correct
    challenge.totalIncorrect += entry.incorrect
    try challenge.update(db)
    try device.updateChanges(db, with: { innerDevice in
      innerDevice.latestChange = max(innerDevice.latestChange, entry.timestamp)
    })

    if buryRelatedChallenges {
      let minimumDue = entry.timestamp.addingTimeInterval(.day)
      let updates = try Sqlite.Challenge
        .filter(Sqlite.Challenge.Columns.challengeTemplateId == challenge.challengeTemplateId &&
          (Sqlite.Challenge.Columns.due == nil || Sqlite.Challenge.Columns.due < minimumDue)
        )
        .updateAll(db, Sqlite.Challenge.Columns.due <- minimumDue)
      DDLogInfo("Buried \(updates) challenge(s)")
    }
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
              templateDigest: FlakeID(rawValue: $0.challenge.challengeTemplateId),
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
  /// Watch this db queue for changes.
  func monitorDatabaseQueue(_ dbQueue: DatabaseQueue) throws {
    if try runMigrations(on: dbQueue) {
      updateChangeCount(.done)
    }
    allMetadata = try dbQueue.read { db in
      try Self.fetchAllMetadata(from: db)
    }
    deviceRecord = try currentDeviceRecord()
    flakeMaker = FlakeMaker(instanceNumber: Int(deviceRecord.id!))
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
      Sqlite.Challenge.all(),
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
          self?.updateChangeCount(.done)
        }
      )
  }

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

  /// Makes sure there is a device record for the current device in this database.
  func currentDeviceRecord() throws -> Sqlite.Device {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.write { db in
      try currentDeviceRecord(in: db)
    }
  }

  /// Given an open database connection, returns the device record for the current device.
  func currentDeviceRecord(in db: Database) throws -> Sqlite.Device {
    guard let uuid = device.identifierForVendor?.uuidString else {
      throw Error.noDeviceUUID
    }
    if var existingRecord = try Sqlite.Device.fetchOne(db, key: ["uuid": uuid]) {
      try existingRecord.updateChanges(db, with: { deviceRecord in
        deviceRecord.name = device.name
      })
      return existingRecord
    } else {
      var record = Sqlite.Device(uuid: uuid, name: device.name, latestChange: Date())
      try record.insert(db)
      return record
    }
  }

  func createInitialDeviceIdentifier(in db: Database) throws -> Int64 {
    guard let uuid = device.identifierForVendor?.uuidString else {
      throw Error.noDeviceUUID
    }
    try db.execute(sql: "INSERT INTO device (uuid, name) VALUES (?, ?)", arguments: [uuid, device.name])
    return db.lastInsertedRowID
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
      var newRecord = Sqlite.NoteText(id: nil, text: noteText, noteId: identifier)
      try newRecord.insert(db)
      return newRecord.id
    }
  }

  func writeNote(_ note: Note, with identifier: Note.Identifier, to db: Database) throws {
    let sqliteNote = Sqlite.Note(
      id: identifier,
      title: note.metadata.title,
      modifiedTimestamp: note.metadata.timestamp,
      modifiedDevice: Int64(flakeMaker!.instanceNumber),
      hasText: note.text != nil,
      deleted: false
    )
    try sqliteNote.save(db)

    // Make sure we have the right timestamp in the device table
    var device = try currentDeviceRecord(in: db)
    device.latestChange = max(note.metadata.timestamp, device.latestChange)
    try device.update(db)

    try writeNoteText(note.text, with: identifier, to: db)
    let inMemoryHashtags = Set(note.metadata.hashtags)
    let onDiskHashtags = ((try? sqliteNote.hashtags.fetchAll(db)) ?? [])
      .asSet()
    for newHashtag in inMemoryHashtags.subtracting(onDiskHashtags) {
      let associationRecord = Sqlite.NoteHashtag(noteId: identifier, hashtag: newHashtag)
      try associationRecord.save(db)
    }
    for obsoleteHashtag in onDiskHashtags.subtracting(inMemoryHashtags) {
      let deleted = try Sqlite.NoteHashtag.deleteOne(db, key: ["noteId": identifier.rawValue, "hashtag": obsoleteHashtag])
      assert(deleted)
    }

    for template in note.challengeTemplates where template.templateIdentifier == nil {
      template.templateIdentifier = flakeMaker.nextValue()
    }
    let inMemoryChallengeTemplates = Set(note.challengeTemplates.map { $0.templateIdentifier! })
    let onDiskChallengeTemplates = ((try? sqliteNote.challengeTemplates.fetchAll(db)) ?? [])
      .map { $0.id }
      .asSet()

    let today = Date()
    let newChallengeDelay = Self.scheduler.learningIntervals.last ?? 0
    for newTemplateIdentifier in inMemoryChallengeTemplates.subtracting(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == newTemplateIdentifier })!
      let templateString = template.rawValue
      let record = Sqlite.ChallengeTemplate(
        id: newTemplateIdentifier,
        type: template.type.rawValue,
        rawValue: templateString,
        noteId: identifier
      )
      try record.insert(db)
      for index in template.challenges.indices {
        var challengeRecord = Sqlite.Challenge(
          index: index,
          due: today /* .addingTimeInterval(newChallengeDelay.fuzzed()) */,
          challengeTemplateId: newTemplateIdentifier.rawValue,
          modifiedDevice: Int64(flakeMaker!.instanceNumber),
          timestamp: note.metadata.timestamp
        )
        try challengeRecord.insert(db)
      }
    }
    for modifiedTemplateIdentifier in inMemoryChallengeTemplates.intersection(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == modifiedTemplateIdentifier })!
      guard var record = try Sqlite.ChallengeTemplate.fetchOne(db, key: modifiedTemplateIdentifier.rawValue) else {
        assertionFailure("Should be a record")
        continue
      }
      record.rawValue = template.rawValue
      try record.update(db, columns: [Sqlite.ChallengeTemplate.Columns.rawValue])
    }
    for obsoleteTemplateIdentifier in onDiskChallengeTemplates.subtracting(inMemoryChallengeTemplates) {
      let deleted = try Sqlite.ChallengeTemplate.deleteOne(db, key: obsoleteTemplateIdentifier.rawValue)
      assert(deleted)
    }
  }

  static func fetchAllMetadata(from db: Database) throws -> [Note.Identifier: Note.Metadata] {
    let metadata = try Sqlite.Note
      .filter(Sqlite.Note.Columns.deleted == false)
      .including(all: Sqlite.Note.noteHashtags)
      .asRequest(of: Sqlite.NoteMetadata.self)
      .fetchAll(db)
    let tuples = metadata.map { metadataItem -> (key: Note.Identifier, value: Note.Metadata) in
      let metadata = Note.Metadata(
        timestamp: metadataItem.modifiedTimestamp,
        hashtags: metadataItem.noteHashtags.map { $0.hashtag },
        title: metadataItem.title,
        containsText: metadataItem.hasText
      )
      let noteIdentifier = Note.Identifier(rawValue: metadataItem.id)
      return (key: noteIdentifier, value: metadata)
    }
    return Dictionary(uniqueKeysWithValues: tuples)
  }

  func loadNote(with identifier: Note.Identifier, from db: Database) throws -> Note {
    guard
      let sqliteNote = try Sqlite.Note.fetchOne(db, key: identifier.rawValue),
      !sqliteNote.deleted
    else {
      throw Error.noSuchNote
    }
    let hashtagRecords = try Sqlite.NoteHashtag.filter(Sqlite.NoteHashtag.Columns.noteId == identifier.rawValue).fetchAll(db)
    let hashtags = hashtagRecords.map { $0.hashtag }
    let challengeTemplateRecords = try Sqlite.ChallengeTemplate
      .filter(Sqlite.ChallengeTemplate.Columns.noteId == identifier.rawValue)
      .fetchAll(db)
    let challengeTemplates = try challengeTemplateRecords.map { challengeTemplateRecord -> ChallengeTemplate in
      try Self.challengeTemplate(from: challengeTemplateRecord)
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

  static func challengeTemplate(identifier: FlakeID, database: Database) throws -> ChallengeTemplate {
    guard let record = try Sqlite.ChallengeTemplate.fetchOne(database, key: identifier.rawValue) else {
      throw Error.unknownChallengeTemplate
    }
    return try challengeTemplate(from: record)
  }

  static func challengeTemplate(
    from challengeTemplateRecord: Sqlite.ChallengeTemplate
  ) throws -> ChallengeTemplate {
    guard let klass = ChallengeTemplateType.classMap[challengeTemplateRecord.type] else {
      throw Error.unknownChallengeType
    }
    guard let template = klass.init(rawValue: challengeTemplateRecord.rawValue) ?? klass.init(rawValue: challengeTemplateRecord.rawValue.yamlUnescaped) else {
      throw Error.cannotDecodeTemplate
    }
    template.templateIdentifier = challengeTemplateRecord.id
    return template
  }

  /// Makes sure the database is up-to-date.
  /// - returns: true if migrations ran.
  func runMigrations(on databaseQueue: DatabaseQueue) throws -> Bool {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("initialSchema") { database in
      try Sqlite.Note.createV1Table(in: database)
      try Sqlite.NoteText.createV1Table(in: database)

      try database.create(virtualTable: "noteFullText", using: FTS5()) { table in
        table.synchronize(withTable: "noteText")
        table.column("text")
        table.tokenizer = .porter(wrapping: .unicode61())
      }

      try database.create(table: "hashtag", body: { table in
        table.column("id", .text).primaryKey()
      })

      try Sqlite.NoteHashtag.createV1Table(in: database)
      try Sqlite.ChallengeTemplate.createV1Table(in: database)
      try Sqlite.Challenge.createV1Table(in: database)

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

    migrator.registerMigration("addChallengeFactor") { database in
      try database.alter(table: "challenge", body: { table in
        table.add(column: "spacedRepetitionFactor", .double).notNull().defaults(to: 2.5)
        table.add(column: "lapseCount", .double).notNull().defaults(to: 0)
        table.add(column: "idealInterval", .double)
      })
    }

    migrator.registerMigrationWithDeferredForeignKeyCheck("flake-ids") { database in
      try database.create(table: "device", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("uuid", .text).notNull().unique().indexed()
        table.column("name", .text).notNull()
      })
      let deviceID = try self.createInitialDeviceIdentifier(in: database)
      let flakeMaker = FlakeMaker(instanceNumber: Int(deviceID))
      try Sqlite.Note.migrateTableFromV1ToV2(in: database, flakeMaker: flakeMaker)
    }

    migrator.registerMigration("no-hashtag-table") { database in
      try Sqlite.NoteHashtag.migrateTableFromV2ToV3(in: database)
      try database.drop(table: "hashtag")
    }

    migrator.registerMigration("latestChangePerDevice") { database in
      try database.alter(table: "device", body: { table in
        table.add(column: "latestChange", .datetime).notNull().defaults(to: Date())
      })

      let currentDevice = try self.currentDeviceRecord(in: database)
      try Sqlite.Challenge.migrateTableFromV2ToV3(in: database, currentDeviceID: currentDevice.id!)
    }

    migrator.registerMigration("noteTombstone") { database in
      try database.alter(table: "note", body: { table in
        table.add(column: "deleted", .boolean).notNull().defaults(to: false)
      })
    }

    let priorMigrations = try migrator.appliedMigrations(in: databaseQueue)
    try migrator.migrate(databaseQueue)
    let postMigrations = try migrator.appliedMigrations(in: databaseQueue)
    return priorMigrations != postMigrations
  }
}

private extension Sqlite.Challenge {
  var item: SpacedRepetitionScheduler.Item {
    if let due = due, let lastReview = lastReview {
      let interval = due.timeIntervalSince(lastReview)
      assert(interval > 0)
      return SpacedRepetitionScheduler.Item(
        learningState: .review,
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? .day,
        factor: spacedRepetitionFactor
      )
    } else {
      // Create an item that's *just about to graduate* if we've never seen it before.
      // That's because we make new items due "last learning interval" after creation
      return SpacedRepetitionScheduler.Item(
        learningState: .learning(step: NoteSqliteStorage.scheduler.learningIntervals.count),
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? 0,
        factor: spacedRepetitionFactor
      )
    }
  }

  mutating func applyItem(_ item: SpacedRepetitionScheduler.Item, on date: Date, from deviceID: Int64) {
    reviewCount = item.reviewCount
    lapseCount = item.lapseCount
    spacedRepetitionFactor = item.factor
    lastReview = date
    idealInterval = item.interval
    due = date.addingTimeInterval(item.interval.fuzzed())
    timestamp = date
    modifiedDevice = deviceID
  }
}

private extension Sqlite.StudyLogEntry {
  var cardAnswer: CardAnswer {
    if correct > 0, incorrect == 0 {
      return .good
    }
    if correct > 0, incorrect == 1 {
      return .hard
    }
    return .again
  }
}

private extension String {
  var yamlUnescaped: String {
    do {
      return try YAMLDecoder().decode(String.self, from: self, userInfo: [:])
    } catch {
      return ""
    }
  }
}

private extension Database {
  func updateDeviceTable(with knowledge: VersionVector) throws {
    for (uuid, date) in knowledge.versions {
      if var device = try Sqlite.Device.filter(key: ["uuid": uuid]).fetchOne(self) {
        device.latestChange = max(device.latestChange, date)
        try device.save(self)
      } else {
        var device = Sqlite.Device(id: nil, uuid: uuid, name: "Unknown", latestChange: date)
        try device.insert(self)
      }
    }
  }
}

private extension DatabaseQueue {
  var deviceVersionVector: VersionVector {
    read { db in
      let devices = (try? Sqlite.Device.fetchAll(db)) ?? []
      return VersionVector(devices)
    }
  }

  /// Merges new content from another storage container into this storage container.
  func merge(remoteQueue: DatabaseQueue) throws -> MergeResult {
    let localKnowledge = deviceVersionVector
    let remoteKnowlege = remoteQueue.deviceVersionVector
    var result = MergeResult()
    try remoteQueue.read { remoteDatabase in
      try write { localDatabase in
        result += try VersionVector.merge(
          recordType: Sqlite.Note.MergeInfo.self,
          from: remoteDatabase,
          sourceKnowledge: remoteKnowlege,
          to: localDatabase,
          destinationKnowledge: localKnowledge
        )
        result += try VersionVector.merge(
          recordType: Sqlite.Challenge.MergeInfo.self,
          from: remoteDatabase,
          sourceKnowledge: remoteKnowlege,
          to: localDatabase,
          destinationKnowledge: localKnowledge
        )
        let combinedKnowledge = localKnowledge.union(remoteKnowlege)
        try localDatabase.updateDeviceTable(with: combinedKnowledge)
      }
    }
    return result
  }
}

private extension VersionVector {
  init(_ devices: [Sqlite.Device]) {
    for device in devices {
      versions[device.uuid] = device.latestChange
    }
  }
}

extension UIDocument.State: CustomStringConvertible {
  public var description: String {
    var strings: [String] = []
    if self.contains(.closed) { strings.append("Closed") }
    if self.contains(.editingDisabled) { strings.append("Editing Disabled") }
    if self.contains(.inConflict) { strings.append("Conflict") }
    if self.contains(.normal) { strings.append("Normal") }
    if self.contains(.progressAvailable) { strings.append("Progress available") }
    if self.contains(.savingError) { strings.append("Saving error") }
    return strings.joined(separator: ", ")
  }
}
