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
  let deviceID: String
  /// The specific sequence number for this change on this device.
  let updateSequenceNumber: Int64
}

/// Implementation of the NoteSqliteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
// TODO: Figure out how to break this apart
// swiftlint:disable:next type_body_length
public final class NoteDatabase: UIDocument {
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
    case missingMigrationScript = "Could not find a required migration script."
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
    // Remove-on-deinit doesn't apply to UIDocument, it seems to me. These have an explicit open/close lifecycle.
    NotificationCenter.default.removeObserver(self) // swiftlint:disable:this notification_center_detachment
    super.close { success in
      self.cleanupAfterClose()
      completionHandler?(success)
    }
  }

  private func cleanupAfterClose() {
    deviceRecord = nil
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
  public func merge(other: NoteDatabase) throws -> MergeResult {
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
    let identifier = UUID().uuidString
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
        SELECT content.*
        FROM content
        JOIN noteFullText
          ON noteFullText.rowid = content.rowid
          AND noteFullText MATCH ?
        """
        let noteTexts = try ContentRecord.fetchAll(db, sql: sql, arguments: [pattern])
        return noteTexts.map { $0.noteId }
      } else {
        let noteTexts = try ContentRecord.fetchAll(db)
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
      guard var note = try NoteRecord.filter(key: noteIdentifier).fetchOne(db) else {
        return
      }
      let updateKey = try self.updateKey(changeDescription: "DELETE NOTE \(noteIdentifier)", in: db)
      try note.contentRecords.deleteAll(db)
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
      let challengeRequest: QueryInterfaceRequest<PromptStatistics>
      if let noteIdentifier = noteIdentifier {
        guard let note = try NoteRecord.fetchOne(db, key: noteIdentifier) else {
          throw Error.noSuchNote
        }
        challengeRequest = note.challenges
      } else {
        challengeRequest = PromptStatistics.all()
      }
      let records = try challengeRequest
        .filter(PromptStatistics.Columns.due == nil || PromptStatistics.Columns.due <= date)
        .fetchAll(db)
      return records.map {
        ChallengeIdentifier(noteId: $0.noteId, promptKey: $0.promptKey, promptIndex: Int($0.promptIndex))
      }
    }
  }

  public func challenge(
    challengeIdentifier: ChallengeIdentifier
  ) throws -> Prompt {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      let templateIdentifier = ChallengeTemplateIdentifier(noteId: challengeIdentifier.noteId, promptKey: challengeIdentifier.promptKey)
      let template = try Self.challengeTemplate(identifier: templateIdentifier, database: db)
      return template.challenges[Int(challengeIdentifier.promptIndex)]
    }
  }

  internal func countOfTextRows() throws -> Int {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      try ContentRecord.fetchCount(db)
    }
  }

  public var assetKeys: [String] {
    do {
      guard let dbQueue = dbQueue else {
        throw Error.databaseIsNotOpen
      }
      return try dbQueue.read { db in
        let request = AssetRecord.select([AssetRecord.Columns.id])
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
      guard let asset = try AssetRecord.fetchOne(db, key: String(fileWrapperKey)) else {
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
      let asset = AssetRecord(id: key, data: data)
      try asset.save(db)
      return key
    }
  }

  public func recordStudyEntry(_ entry: StudyLog.Entry, buryRelatedChallenges: Bool) throws {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    try dbQueue.write { db in
      var record = StudyLogEntryRecord(
        id: nil,
        timestamp: entry.timestamp,
        correct: entry.statistics.correct,
        incorrect: entry.statistics.incorrect,
        noteId: entry.identifier.noteId,
        promptKey: entry.identifier.promptKey,
        promptIndex: entry.identifier.promptIndex
      )
      try record.insert(db)
      let updateKey = try self.updateKey(changeDescription: "UPDATE CHALLENGE \(entry.identifier.promptIndex) WHERE CHALLENGE TEMPLATE = \(entry.identifier.promptKey) BURY = \(buryRelatedChallenges)", in: db)
      try Self.updateChallenge(entry.identifier, for: record, in: db, buryRelatedChallenges: buryRelatedChallenges, updateKey: updateKey)
    }
    notesDidChangeSubject.send()
  }

  private static func updateChallenge(
    _ identifier: ChallengeIdentifier,
    for entry: StudyLogEntryRecord,
    in db: Database,
    buryRelatedChallenges: Bool,
    updateKey: UpdateKey
  ) throws {
    var challenge = try PromptStatistics.fetchOne(db, key: identifier)!
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
      let updates = try PromptStatistics
        .filter(PromptStatistics.Columns.noteId == identifier.noteId && PromptStatistics.Columns.promptKey == identifier.promptKey &&
          (PromptStatistics.Columns.due == nil || PromptStatistics.Columns.due < minimumDue)
        )
        .updateAll(db, PromptStatistics.Columns.due <- minimumDue, PromptStatistics.Columns.modifiedDevice <- updateKey.deviceID, PromptStatistics.Columns.updateSequenceNumber <- updateKey.updateSequenceNumber)
      Logger.shared.info("Buried \(updates) challenge(s)")
    }
  }

  public var studyLog: StudyLog {
    var log = StudyLog()
    do {
      guard let dbQueue = dbQueue else {
        throw Error.databaseIsNotOpen
      }
      let entries = try dbQueue.read { db -> [StudyLogEntryInfo] in
        let request = StudyLogEntryRecord
          .order(StudyLogEntryRecord.Columns.timestamp)
          .including(required: StudyLogEntryRecord.challenge)
        return try StudyLogEntryInfo
          .fetchAll(db, request)
      }
      entries
        .map {
          StudyLog.Entry(
            timestamp: $0.studyLogEntry.timestamp,
            identifier: ChallengeIdentifier(
              noteId: $0.studyLogEntry.noteId,
              promptKey: $0.studyLogEntry.promptKey,
              promptIndex: $0.studyLogEntry.promptIndex
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

  /// Computes a studySession for the relevant pages in the notebook.
  /// - parameter filter: An optional filter closure to determine if the page's challenges should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining challenge eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  public func studySession(
    filter: ((Note.Identifier, Note.Metadata) -> Bool)? = nil,
    date: Date = Date(),
    completion: @escaping (StudySession) -> Void
  ) {
    DispatchQueue.global(qos: .default).async {
      let result = self.synchronousStudySession(filter: filter, date: date)
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  /// Blocking function that gets the study session. Safe to call from background threads. Only `internal` and not `private` so tests can call it.
  // TODO: On debug builds, this is *really* slow. Worth optimizing.
  internal func synchronousStudySession(
    filter: ((Note.Identifier, Note.Metadata) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    return allMetadata
      .filter { filter($0.key, $0.value) }
      .map { (name, reviewProperties) -> StudySession in
        let challengeIdentifiers = try? eligibleChallengeIdentifiers(before: date, limitedTo: name)
        return StudySession(
          challengeIdentifiers ?? [],
          properties: CardDocumentProperties(
            documentName: name,
            attributionMarkdown: reviewProperties.title
          )
        )
      }
      .reduce(into: StudySession()) { $0 += $1 }
  }

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedChallenges: Bool) throws {
    let entries = studySession.results.map { tuple -> StudyLog.Entry in
      StudyLog.Entry(timestamp: date, identifier: tuple.key, statistics: tuple.value)
    }
    for entry in entries {
      try recordStudyEntry(entry, buryRelatedChallenges: buryRelatedChallenges)
    }
  }

  /// All hashtags used across all pages, sorted.
  public var hashtags: [String] {
    let hashtags = allMetadata.values.reduce(into: Set<String>()) { hashtags, props in
      hashtags.formUnion(props.hashtags)
    }
    return Array(hashtags).sorted()
  }
}

// MARK: - Private

private extension NoteDatabase {
  /// Watch this db queue for changes.
  func monitorDatabaseQueue(_ dbQueue: DatabaseQueue) throws {
    if try runMigrations(on: dbQueue) {
      updateChangeCount(.done)
    }
    try dbQueue.recoverFullTextIndexIfNeeded()
    allMetadata = try dbQueue.read { db in
      try Self.fetchAllMetadata(from: db)
    }
    deviceRecord = try currentDeviceRecord()
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
      ContentRecord.all(),
      NoteHashtagRecord.all(),
      PromptStatistics.all(),
      StudyLogEntryRecord.all(),
      AssetRecord.all(),
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

  func writePrimaryTextContent(_ noteText: String?, with identifier: Note.Identifier, to db: Database) throws {
    guard let noteText = noteText else {
      return
    }
    if var existingRecord = try ContentRecord.fetchOne(db, key: ["noteId": identifier, "key": "primary"]) {
      existingRecord.text = noteText
      try existingRecord.update(db)
    } else {
      let newRecord = ContentRecord(
        text: noteText,
        noteId: identifier,
        key: "primary",
        role: "primary",
        mimeType: "text/markdown"
      )
      try newRecord.insert(db)
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
    let changeLog = ChangeLogRecord(
      deviceID: device.uuid,
      updateSequenceNumber: device.updateSequenceNumber,
      timestamp: Date(),
      changeDescription: changeDescription
    )
    try changeLog.insert(database)
    return UpdateKey(deviceID: device.uuid, updateSequenceNumber: device.updateSequenceNumber)
  }

  // TODO: Make this smaller
  // swiftlint:disable:next function_body_length
  func writeNote(_ note: Note, with identifier: Note.Identifier, to db: Database) throws {
    var note = note
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

    try writePrimaryTextContent(note.text, with: identifier, to: db)
    let inMemoryHashtags = Set(note.metadata.hashtags)
    let onDiskHashtags = ((try? sqliteNote.hashtags.fetchAll(db)) ?? [])
      .asSet()
    for newHashtag in inMemoryHashtags.subtracting(onDiskHashtags) {
      let associationRecord = NoteHashtagRecord(noteId: identifier, hashtag: newHashtag)
      try associationRecord.save(db)
    }
    for obsoleteHashtag in onDiskHashtags.subtracting(inMemoryHashtags) {
      let deleted = try NoteHashtagRecord.deleteOne(db, key: ["noteId": identifier, "hashtag": obsoleteHashtag])
      assert(deleted)
    }

    for index in note.challengeTemplates.indices {
      if note.challengeTemplates[index].templateIdentifier == nil {
        note.challengeTemplates[index].templateIdentifier = ChallengeTemplateIdentifier(noteId: identifier, promptKey: UUID().uuidString)
      } else {
        note.challengeTemplates[index].templateIdentifier!.noteId = identifier
      }
    }
    let inMemoryChallengeTemplates = Set(note.challengeTemplates.map { $0.templateIdentifier! })
    let onDiskChallengeTemplates = ((try? sqliteNote.prompts.fetchAll(db)) ?? [])
      .map { ChallengeTemplateIdentifier(noteId: $0.noteId, promptKey: $0.key) }
      .asSet()

    let today = Date()
    let newChallengeDelay = Self.scheduler.learningIntervals.last ?? 0
    for newTemplateIdentifier in inMemoryChallengeTemplates.subtracting(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == newTemplateIdentifier })!
      let record = ContentRecord(
        text: template.rawValue,
        noteId: template.templateIdentifier!.noteId,
        key: template.templateIdentifier!.promptKey,
        role: template.type.rawValue,
        mimeType: "text/markdown"
      )
      do {
        try record.insert(db)
      } catch {
        Logger.shared.critical("Could not insert content")
        throw error
      }
      for index in template.challenges.indices {
        let updateKey = try self.updateKey(
          changeDescription: "INSERT CHALLENGE \(index) WHERE TEMPLATE = \(newTemplateIdentifier)",
          in: db
        )
        let promptStatistics = PromptStatistics(
          noteId: newTemplateIdentifier.noteId,
          promptKey: newTemplateIdentifier.promptKey,
          promptIndex: Int64(index),
          due: today.addingTimeInterval(newChallengeDelay.fuzzed()),
          modifiedDevice: updateKey.deviceID,
          timestamp: note.metadata.timestamp,
          updateSequenceNumber: updateKey.updateSequenceNumber
        )
        try promptStatistics.insert(db)
      }
    }
    for modifiedTemplateIdentifier in inMemoryChallengeTemplates.intersection(onDiskChallengeTemplates) {
      let template = note.challengeTemplates.first(where: { $0.templateIdentifier == modifiedTemplateIdentifier })!
      guard var record = try ContentRecord.fetchOne(db, key: modifiedTemplateIdentifier) else {
        assertionFailure("Should be a record")
        continue
      }
      record.text = template.rawValue
      try record.update(db, columns: [ContentRecord.Columns.text])
    }
    for obsoleteTemplateIdentifier in onDiskChallengeTemplates.subtracting(inMemoryChallengeTemplates) {
      let deleted = try ContentRecord.deleteOne(db, key: obsoleteTemplateIdentifier)
      assert(deleted)
    }
  }

  static func fetchAllMetadata(from db: Database) throws -> [Note.Identifier: Note.Metadata] {
    let metadata = try NoteRecord
      .filter(NoteRecord.Columns.deleted == false)
      .including(all: NoteRecord.noteHashtags)
      .asRequest(of: NoteMetadataRecord.self)
      .fetchAll(db)
    let tuples = metadata.map { metadataItem -> (key: Note.Identifier, value: Note.Metadata) in
      let metadata = Note.Metadata(
        timestamp: metadataItem.modifiedTimestamp,
        hashtags: metadataItem.noteHashtags.map { $0.hashtag },
        title: metadataItem.title,
        containsText: metadataItem.hasText
      )
      return (key: metadataItem.id, value: metadata)
    }
    return Dictionary(uniqueKeysWithValues: tuples)
  }

  func loadNote(with identifier: Note.Identifier, from db: Database) throws -> Note {
    guard
      let sqliteNote = try NoteRecord.fetchOne(db, key: identifier),
      !sqliteNote.deleted
    else {
      throw Error.noSuchNote
    }
    let hashtagRecords = try NoteHashtagRecord.filter(NoteHashtagRecord.Columns.noteId == identifier).fetchAll(db)
    let hashtags = hashtagRecords.map { $0.hashtag }
    let contentRecords = try ContentRecord.filter(ContentRecord.Columns.noteId == identifier).fetchAll(db)
    let challengeTemplates = try contentRecords
      .filter { $0.role.hasPrefix("prompt=") }
      .map { try Self.challengeTemplate(from: $0) }
    let noteText = contentRecords.first(where: { $0.role == "primary" })?.text
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

  static func challengeTemplate(identifier: ChallengeTemplateIdentifier, database: Database) throws -> ChallengeTemplate {
    guard let record = try ContentRecord.fetchOne(database, key: [ContentRecord.Columns.noteId.rawValue: identifier.noteId, ContentRecord.Columns.key.rawValue: identifier.promptKey]) else {
      throw Error.unknownChallengeTemplate
    }
    return try challengeTemplate(from: record)
  }

  static func challengeTemplate(
    from contentRecord: ContentRecord
  ) throws -> ChallengeTemplate {
    guard let klass = ChallengeTemplateType.classMap[contentRecord.role] else {
      throw Error.unknownChallengeType
    }
    guard var template = klass.init(rawValue: contentRecord.text) else {
      throw Error.cannotDecodeTemplate
    }
    template.templateIdentifier = ChallengeTemplateIdentifier(
      noteId: contentRecord.noteId,
      promptKey: contentRecord.key
    )
    return template
  }

  /// Makes sure the database is up-to-date.
  /// - returns: true if migrations ran.
  func runMigrations(on databaseQueue: DatabaseQueue) throws -> Bool {
    var migrator = DatabaseMigrator()

    try migrator.registerMigrationScript(.initialSchema)
    try migrator.registerMigrationScript(.deviceUUIDKey)
    try migrator.registerMigrationScript(.noFlakeNote)
    try migrator.registerMigrationScript(.noFlakeChallengeTemplate)
    try migrator.registerMigrationScript(.addContentTable, additionalSteps: { database in
      // Recreate the index
      try database.drop(table: "noteFullText")
      try database.create(virtualTable: "noteFullText", using: FTS5()) { table in
        table.synchronize(withTable: "content")
        table.column("text")
        table.tokenizer = .porter(wrapping: .unicode61())
      }
    })
    try migrator.registerMigrationScript(.changeContentKey, additionalSteps: { database in
      // Recreate the index
      try database.drop(table: "noteFullText")
      try database.create(virtualTable: "noteFullText", using: FTS5()) { table in
        table.synchronize(withTable: "content")
        table.column("text")
        table.tokenizer = .porter(wrapping: .unicode61())
      }
    })
    try migrator.registerMigrationScript(.prompts)

    let priorMigrations = try migrator.appliedMigrations(in: databaseQueue)
    try migrator.migrate(databaseQueue)
    let postMigrations = try migrator.appliedMigrations(in: databaseQueue)
    return priorMigrations != postMigrations
  }
}

private extension PromptStatistics {
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
        learningState: .learning(step: NoteDatabase.scheduler.learningIntervals.count),
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

private extension StudyLogEntryRecord {
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
        var device = DeviceRecord(uuid: uuid, name: "Unknown", updateSequenceNumber: updateSequenceNumber)
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

  func recoverFullTextIndexIfNeeded() throws {
    try write { db in
      do {
        try db.execute(sql: "INSERT INTO noteFullText(noteFullText) VALUES('integrity-check')")
        Logger.shared.info("Full text index looks legit")
      } catch {
        Logger.shared.error("Full text index corrupt! Trying to recover.")
        try db.execute(sql: "INSERT INTO noteFullText(noteFullText) VALUES('rebuild')")
        Logger.shared.info("Recovered full text index")
      }
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
          recordType: PromptStatistics.MergeInfo.self,
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

private extension DatabaseMigrator {
  mutating func registerMigrationScript(
    _ migration: MigrationIdentifier,
    additionalSteps: ((Database) throws -> Void)? = nil
  ) throws {
    let bundle = Bundle(for: NoteDatabase.self)
    guard
      let scriptURL = bundle.url(forResource: migration.rawValue, withExtension: "sql"),
      let script = try? String(contentsOf: scriptURL)
    else {
      throw NoteDatabase.Error.missingMigrationScript
    }
    registerMigrationWithDeferredForeignKeyCheck(migration.rawValue) { database in
      try database.execute(sql: script)
      try additionalSteps?(database)
    }
  }
}
