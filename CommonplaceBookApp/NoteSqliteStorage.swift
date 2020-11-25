//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Combine
import Foundation
import GRDB
import GRDBCombine
import Logging
import SpacedRepetitionScheduler
import UIKit

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

/// Identifier for a specific change to the database.
private struct UpdateKey {
  /// The device ID that the change came from.
  let deviceID: Int64
  /// The specific sequence number for this change on this device.
  let updateSequenceNumber: Int64
}

/// Implementation of the NoteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
public final class NoteSqliteStorage: UIDocument, NoteStorage {
  /// Designated initializer.
  public init(
    fileURL: URL,
    device: DeviceIdentifying = UIDevice.current
  ) {
    self.device = device
    self.notesDidChange = notesDidChangeSubject.eraseToAnyPublisher()
    super.init(fileURL: fileURL)
  }

  /// The device that this instance runs on.
  public let device: DeviceIdentifying

  /// The device record associated with this open database on this device. Valid when there is an open database.
  private var deviceRecord: DeviceRecord!

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
          Logger.shared.error("Unexpected error monitoring queue for changes: \(error)")
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

  public typealias IOCompletionHandler = (Bool) -> Void

  override public func open(completionHandler: IOCompletionHandler? = nil) {
    super.open { success in
      Logger.shared.info("UIDocument: Opened '\(self.fileURL.path)' -- success = \(success) state = \(self.documentState)")
      NotificationCenter.default.addObserver(self, selector: #selector(self.handleDocumentStateChanged), name: UIDocument.stateChangedNotification, object: self)
      self.handleDocumentStateChanged()
      completionHandler?(success)
    }
  }

  override public func close(completionHandler: IOCompletionHandler? = nil) {
    NotificationCenter.default.removeObserver(self)
    super.close { success in
      self.cleanupAfterClose()
      completionHandler?(success)
    }
  }

  private func cleanupAfterClose() {
    deviceRecord = nil
    flakeMaker = nil
    metadataUpdatePipeline?.cancel()
    metadataUpdatePipeline = nil
    hasUnsavedChangesPipeline?.cancel()
    hasUnsavedChangesPipeline = nil
    dbQueue = nil
  }

  public func refresh(completionHandler: IOCompletionHandler?) {
    Logger.shared.info("UIDocument: Attempting to refresh content")
    do {
      try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
      completionHandler?(true)
    } catch {
      Logger.shared.error("UIDocument: Error initiating download: \(error)")
      completionHandler?(false)
    }
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
    Logger.shared.info("UIDocument: Handling conflict")
    do {
      var conflictMergeResults = MergeResult()
      for conflictVersion in NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? [] {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("grail")
        try conflictVersion.replaceItem(at: tempURL, options: [])
        defer {
          try? FileManager.default.removeItem(at: tempURL)
        }
        let conflictQueue = try memoryDatabaseQueue(fileURL: tempURL)
        if let dbQueue = dbQueue {
          let result = try dbQueue.merge(remoteQueue: conflictQueue)
          Logger.shared.info("UIDocument: Merged conflict version: \(result)")
          conflictMergeResults += result
        } else {
          Logger.shared.info("UIDocument: Trying to resolve conflict but dbQueue is nil?")
          dbQueue = conflictQueue
        }
        conflictVersion.isResolved = true
        try conflictVersion.remove()
      }
      Logger.shared.info("UIDocument: Finished resolving conflicts")
      try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
      if !conflictMergeResults.isEmpty {
        notesDidChangeSubject.send()
      }
    } catch {
      Logger.shared.error("UIDocument: Unexpected error resolving conflict: \(error)")
    }
  }

  override public func read(from url: URL) throws {
    // TODO: Optionally merge the changes from disk into memory?
    Logger.shared.info("UIDocument: Reading content from '\(url.path)'")
    let dbQueue = try memoryDatabaseQueue(fileURL: url)
    DispatchQueue.main.async {
      if let inMemoryQueue = self.dbQueue {
        if dbQueue.deviceVersionVector == inMemoryQueue.deviceVersionVector {
          Logger.shared.info("UIDocument: On-disk content is the same as memory; ignoring")
        } else if dbQueue.deviceVersionVector > inMemoryQueue.deviceVersionVector {
          Logger.shared.info("UIDocument: On-disk data is strictly greater than in-memory; overwriting")
          self.dbQueue = dbQueue
        } else {
          Logger.shared.info("UIDocument: **Merging** disk contents with memory.\nDisk: \(dbQueue.deviceVersionVector)\nMemory: \(inMemoryQueue.deviceVersionVector)")
          do {
            let result = try inMemoryQueue.merge(remoteQueue: dbQueue)
            Logger.shared.info("UIDocument: Merged disk results \(result)")
            if !result.isEmpty {
              self.notesDidChangeSubject.send()
            }
          } catch {
            Logger.shared.error("UIDocument: Could not merge disk contents! \(error)")
          }
        }
      } else {
        Logger.shared.info("UIDocument: Nothing in memory, using the disk image")
        self.dbQueue = dbQueue
      }
    }
  }

  override public func writeContents(
    _ contents: Any,
    to url: URL,
    for saveOperation: UIDocument.SaveOperation,
    originalContentsURL: URL?
  ) throws {
    guard let dbQueue = dbQueue, hasUnsavedChanges else {
      return
    }
    Logger.shared.info("UIDocument: Writing content to '\(url.path)'")
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
      guard var note = try NoteRecord.filter(key: noteIdentifier.rawValue).fetchOne(db) else {
        return
      }
      let updateKey = try self.updateKey(changeDescription: "DELETE NOTE \(noteIdentifier)", in: db)
      try note.noteText.deleteAll(db)
      try note.challengeTemplates.deleteAll(db)
      note.deleted = true
      note.modifiedDevice = updateKey.deviceID
      note.modifiedTimestamp = Date()
      note.updateSequenceNumber = updateKey.updateSequenceNumber
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
      let challengeRequest: QueryInterfaceRequest<ChallengeRecord>
      if let noteIdentifier = noteIdentifier {
        guard let note = try NoteRecord.fetchOne(db, key: noteIdentifier.rawValue) else {
          throw Error.noSuchNote
        }
        challengeRequest = note.challenges
      } else {
        challengeRequest = ChallengeRecord.all()
      }
      let records = try challengeRequest
        .filter(ChallengeRecord.Columns.due == nil || ChallengeRecord.Columns.due <= date)
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
      Logger.shared.error("Unexpected error getting asset keys: \(error)")
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
        let owningTemplate = try ChallengeTemplateRecord.fetchOne(db, key: templateKey.rawValue),
        let challenge = try owningTemplate.challenges.filter(ChallengeRecord.Columns.index == entry.identifier.index).fetchOne(db)
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
      let updateKey = try self.updateKey(changeDescription: "UPDATE CHALLENGE \(entry.identifier.index) WHERE CHALLENGE TEMPLATE = \(templateKey) BURY = \(buryRelatedChallenges)", in: db)
      try Self.updateChallenge(for: record, in: db, buryRelatedChallenges: buryRelatedChallenges, updateKey: updateKey)
    }
    notesDidChangeSubject.send()
  }

  private static func updateChallenge(
    for entry: Sqlite.StudyLogEntry,
    in db: Database,
    buryRelatedChallenges: Bool,
    updateKey: UpdateKey
  ) throws {
    var challenge = try ChallengeRecord.fetchOne(db, key: entry.challengeId)!
    let delay: TimeInterval
    if let lastReview = challenge.lastReview, let idealInterval = challenge.idealInterval {
      let idealDate = lastReview.addingTimeInterval(idealInterval)
      delay = max(entry.timestamp.timeIntervalSince(idealDate), 0)
    } else {
      delay = 0
    }
    let schedulingOptions = Self.scheduler.scheduleItem(challenge.item, afterDelay: delay)
    let outcome = schedulingOptions[entry.cardAnswer] ?? schedulingOptions[.again]!

    challenge.applyItem(outcome, on: entry.timestamp, updateKey: updateKey)
    challenge.totalCorrect += entry.correct
    challenge.totalIncorrect += entry.incorrect
    try challenge.update(db)

    if buryRelatedChallenges {
      let minimumDue = entry.timestamp.addingTimeInterval(.day)
      let updates = try ChallengeRecord
        .filter(ChallengeRecord.Columns.challengeTemplateId == challenge.challengeTemplateId &&
          (ChallengeRecord.Columns.due == nil || ChallengeRecord.Columns.due < minimumDue)
        )
        .updateAll(db, ChallengeRecord.Columns.due <- minimumDue, ChallengeRecord.Columns.modifiedDevice <- updateKey.deviceID, ChallengeRecord.Columns.updateSequenceNumber <- updateKey.updateSequenceNumber)
      Logger.shared.info("Buried \(updates) challenge(s)")
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
      Logger.shared.error("Unexpected error fetching study log: \(error)")
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
      NoteRecord.all(),
    ]).publisher(in: dbQueue)
      .tryMap { db in try Self.fetchAllMetadata(from: db) }
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            Logger.shared.error("Unexpected error monitoring database: \(error)")
          case .finished:
            Logger.shared.info("Monitoring pipeline shutting down")
          }
        },
        receiveValue: { [weak self] allMetadata in
          self?.allMetadata = allMetadata
        }
      )
    hasUnsavedChangesPipeline = DatabaseRegionObservation(tracking: [
      NoteRecord.all(),
      Sqlite.NoteText.all(),
      Sqlite.NoteHashtag.all(),
      ChallengeRecord.all(),
      Sqlite.StudyLogEntry.all(),
      Sqlite.Asset.all(),
    ]).publisher(in: dbQueue)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            Logger.shared.error("Unexpected error monitoring database: \(error)")
          case .finished:
            Logger.shared.info("hasUnsavedChanges shutting down")
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
          Logger.shared.info("Unable to load \(coordinatedURL.path): \(error)")
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
  func currentDeviceRecord() throws -> DeviceRecord {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.write { db in
      try currentDeviceRecord(in: db)
    }
  }

  /// Given an open database connection, returns the device record for the current device.
  func currentDeviceRecord(in db: Database) throws -> DeviceRecord {
    guard let uuid = device.identifierForVendor?.uuidString else {
      throw Error.noDeviceUUID
    }
    if var existingRecord = try DeviceRecord.fetchOne(db, key: ["uuid": uuid]) {
      try existingRecord.updateChanges(db, with: { deviceRecord in
        deviceRecord.name = device.name
      })
      return existingRecord
    } else {
      var record = DeviceRecord(uuid: uuid, name: device.name, updateSequenceNumber: -1)
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

  /// Creates a change log entry for a change, and returns the key identifying the change.
  /// - Parameters:
  ///   - changeDescription: The change being made
  ///   - database: The writeable database in which the change will be made.
  /// - Throws: Database errors
  /// - Returns: The key identifying this change.
  func updateKey(
    changeDescription: String,
    in database: Database
  ) throws -> UpdateKey {
    var device = try currentDeviceRecord(in: database)
    device.updateSequenceNumber += 1
    try device.update(database)
    let changeLog = Sqlite.ChangeLog(
      deviceID: device.id!,
      updateSequenceNumber: device.updateSequenceNumber,
      timestamp: Date(),
      changeDescription: changeDescription
    )
    try changeLog.insert(database)
    return UpdateKey(deviceID: device.id!, updateSequenceNumber: device.updateSequenceNumber)
  }

  func writeNote(_ note: Note, with identifier: Note.Identifier, to db: Database) throws {
    let updateKey = try self.updateKey(changeDescription: "SAVE NOTE \(identifier)", in: db)
    let sqliteNote = NoteRecord(
      id: identifier,
      title: note.metadata.title,
      modifiedTimestamp: note.metadata.timestamp,
      modifiedDevice: updateKey.deviceID,
      hasText: note.text != nil,
      deleted: false,
      updateSequenceNumber: updateKey.updateSequenceNumber
    )
    try sqliteNote.save(db)

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
      let record = ChallengeTemplateRecord(
        id: newTemplateIdentifier,
        type: template.type.rawValue,
        rawValue: templateString,
        noteId: identifier
      )
      try record.insert(db)
      for index in template.challenges.indices {
        let updateKey = try self.updateKey(
          changeDescription: "INSERT CHALLENGE \(index) WHERE TEMPLATE = \(newTemplateIdentifier)",
          in: db
        )
        var challengeRecord = ChallengeRecord(
          index: index,
          due: today.addingTimeInterval(newChallengeDelay.fuzzed()),
          challengeTemplateId: newTemplateIdentifier.rawValue,
          modifiedDevice: updateKey.deviceID,
          timestamp: note.metadata.timestamp,
          updateSequenceNumber: updateKey.updateSequenceNumber
        )
        try challengeRecord.insert(db)
      }
    }
    for modifiedTemplateIdentifier in inMemoryChallengeTemplates.intersection(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == modifiedTemplateIdentifier })!
      guard var record = try ChallengeTemplateRecord.fetchOne(db, key: modifiedTemplateIdentifier.rawValue) else {
        assertionFailure("Should be a record")
        continue
      }
      record.rawValue = template.rawValue
      try record.update(db, columns: [ChallengeTemplateRecord.Columns.rawValue])
    }
    for obsoleteTemplateIdentifier in onDiskChallengeTemplates.subtracting(inMemoryChallengeTemplates) {
      let deleted = try ChallengeTemplateRecord.deleteOne(db, key: obsoleteTemplateIdentifier.rawValue)
      assert(deleted)
    }
  }

  static func fetchAllMetadata(from db: Database) throws -> [Note.Identifier: Note.Metadata] {
    let metadata = try NoteRecord
      .filter(NoteRecord.Columns.deleted == false)
      .including(all: NoteRecord.noteHashtags)
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
      let sqliteNote = try NoteRecord.fetchOne(db, key: identifier.rawValue),
      !sqliteNote.deleted
    else {
      throw Error.noSuchNote
    }
    let hashtagRecords = try Sqlite.NoteHashtag.filter(Sqlite.NoteHashtag.Columns.noteId == identifier.rawValue).fetchAll(db)
    let hashtags = hashtagRecords.map { $0.hashtag }
    let challengeTemplateRecords = try ChallengeTemplateRecord
      .filter(ChallengeTemplateRecord.Columns.noteId == identifier.rawValue)
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
    guard let record = try ChallengeTemplateRecord.fetchOne(database, key: identifier.rawValue) else {
      throw Error.unknownChallengeTemplate
    }
    return try challengeTemplate(from: record)
  }

  static func challengeTemplate(
    from challengeTemplateRecord: ChallengeTemplateRecord
  ) throws -> ChallengeTemplate {
    guard let klass = ChallengeTemplateType.classMap[challengeTemplateRecord.type] else {
      throw Error.unknownChallengeType
    }
    guard let template = klass.init(rawValue: challengeTemplateRecord.rawValue) else {
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
      try DeviceRecord.createV1Table(in: database)
      try NoteRecord.createV1Table(in: database)
      try Sqlite.NoteText.createV1Table(in: database)
      try Sqlite.NoteHashtag.createV1Table(in: database)
      try ChallengeTemplateRecord.createV1Table(in: database)
      try ChallengeRecord.createV1Table(in: database)
      try Sqlite.StudyLogEntry.createV1Table(in: database)
      try Sqlite.Asset.createV1Table(in: database)
      try Sqlite.ChangeLog.createV1Table(in: database)

      try database.create(virtualTable: "noteFullText", using: FTS5()) { table in
        table.synchronize(withTable: "noteText")
        table.column("text")
        table.tokenizer = .porter(wrapping: .unicode61())
      }
    }

    let priorMigrations = try migrator.appliedMigrations(in: databaseQueue)
    try migrator.migrate(databaseQueue)
    let postMigrations = try migrator.appliedMigrations(in: databaseQueue)
    return priorMigrations != postMigrations
  }
}

private extension ChallengeRecord {
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

  mutating func applyItem(_ item: SpacedRepetitionScheduler.Item, on date: Date, updateKey: UpdateKey) {
    reviewCount = item.reviewCount
    lapseCount = item.lapseCount
    spacedRepetitionFactor = item.factor
    lastReview = date
    idealInterval = item.interval
    due = date.addingTimeInterval(item.interval.fuzzed())
    timestamp = date
    modifiedDevice = updateKey.deviceID
    updateSequenceNumber = updateKey.updateSequenceNumber
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

private extension Database {
  func updateDeviceTable(with knowledge: VersionVector) throws {
    for (uuid, updateSequenceNumber) in knowledge.versions {
      if var device = try DeviceRecord.filter(key: ["uuid": uuid]).fetchOne(self) {
        device.updateSequenceNumber = max(device.updateSequenceNumber, updateSequenceNumber)
        try device.save(self)
      } else {
        var device = DeviceRecord(id: nil, uuid: uuid, name: "Unknown", updateSequenceNumber: updateSequenceNumber)
        try device.insert(self)
      }
    }
  }
}

private extension DatabaseQueue {
  var deviceVersionVector: VersionVector {
    read { db in
      let devices = (try? DeviceRecord.fetchAll(db)) ?? []
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
          recordType: NoteRecord.MergeInfo.self,
          from: remoteDatabase,
          sourceKnowledge: remoteKnowlege,
          to: localDatabase,
          destinationKnowledge: localKnowledge
        )
        result += try VersionVector.merge(
          recordType: ChallengeRecord.MergeInfo.self,
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
  init(_ devices: [DeviceRecord]) {
    for device in devices {
      versions[device.uuid] = device.updateSequenceNumber
    }
  }
}

extension UIDocument.State: CustomStringConvertible {
  public var description: String {
    var strings: [String] = []
    if contains(.closed) { strings.append("Closed") }
    if contains(.editingDisabled) { strings.append("Editing Disabled") }
    if contains(.inConflict) { strings.append("Conflict") }
    if contains(.normal) { strings.append("Normal") }
    if contains(.progressAvailable) { strings.append("Progress available") }
    if contains(.savingError) { strings.append("Saving error") }
    return strings.joined(separator: ", ")
  }
}
