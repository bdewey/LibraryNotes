// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Foundation
import GRDB
import KeyValueCRDT
import Logging
import SpacedRepetitionScheduler
import UIKit
import UniformTypeIdentifiers

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
public struct UpdateIdentifier {
  /// The device ID that the change came from.
  let deviceID: String
  /// The specific sequence number for this change on this device.
  let updateSequenceNumber: Int64
}

extension LegacyNoteDatabase: NoteDatabase {}

/// Implementation of the NoteSqliteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
// TODO: Figure out how to break this apart
// swiftlint:disable:next type_body_length
public final class LegacyNoteDatabase: UIDocument {
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
  public static let scheduler: SchedulingParameters = {
    SchedulingParameters(
      learningIntervals: [.day, 4 * .day],
      goodGraduatingInterval: 7 * .day
    )
  }()

  /// Connection to the in-memory database.
  internal var dbQueue: DatabaseQueue? {
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

  struct StudyLogEntry: Codable {
    var timestamp: Date
    var correct: Int
    var incorrect: Int
    var promptIndex: Int

    init(_ studyLogEntry: StudyLogEntryRecord) {
      self.timestamp = studyLogEntry.timestamp
      self.correct = studyLogEntry.correct
      self.incorrect = studyLogEntry.incorrect
      self.promptIndex = studyLogEntry.promptIndex
    }
  }

  public func exportToKVCRDT(_ fileURL: URL) throws {
    guard let author = Author(UIDevice.current) else {
      throw NoteDatabaseError.noDeviceUUID
    }
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }

    try? FileManager.default.removeItem(at: fileURL)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let crdtDocument = try UIKeyValueDocument(fileURL: fileURL, author: author)
    let crdt = crdtDocument.keyValueCRDT
    let contentRecords = try dbQueue.read { db in
      try ContentRecord.fetchAll(db)
    }
    let tuples = contentRecords.compactMap { record -> (ScopedKey, String)? in
      if record.role != ContentRole.primary.rawValue { return nil }
      return (ScopedKey(scope: record.noteId, key: NoteDatabaseKey.noteText), record.text)
    }
    let map = Dictionary(tuples, uniquingKeysWith: { value, _ in value }).mapValues({ Value.text($0) })
    try crdt.bulkWrite(map)

    let noteMetadata = try dbQueue.read { db in
      try NoteMetadataRecord.request()
        .fetchAll(db)
        .dictionaryMap { (key: $0.id, value: BookNoteMetadata($0)) }
    }

    let bulkMetadata = try noteMetadata.map { (noteId, metadata) -> (ScopedKey, Value) in
      let data = try encoder.encode(metadata)
      let json = String(data: data, encoding: .utf8)!
      return (ScopedKey(scope: noteId, key: NoteDatabaseKey.metadata), .json(json))
    }
    try crdt.bulkWrite(Dictionary(uniqueKeysWithValues: bulkMetadata))

    let promptRecords = try dbQueue.read { db in
      try PromptRecord.fetchAll(db)
    }
    let groupedPromptRecords = Dictionary(grouping: promptRecords, by: { [$0.noteId, $0.promptKey].joined(separator: ".") })

    let promptTuples = try contentRecords.compactMap { record -> (ScopedKey, Value)? in
      if !record.role.hasPrefix("prompt=") { return nil }
      let promptType = PromptType(rawValue: String(record.role.dropFirst(7)))
      let promptRecordKey = [record.noteId, record.key].joined(separator: ".")
      let newKey = PromptCollectionIdentifier(promptType: promptType, count: groupedPromptRecords[promptRecordKey]?.count ?? 0, id: record.key)
      let info = PromptCollectionInfo(contentRecord: record, promptRecords: groupedPromptRecords[promptRecordKey]!)
      let json = String(data: try encoder.encode(info), encoding: .utf8)!
      return (ScopedKey(scope: record.noteId, key: newKey.rawValue), .json(json))
    }
    try crdt.bulkWrite(Dictionary(promptTuples, uniquingKeysWith: { value, _ in value }))

    let binaryContentRecords = try dbQueue.read { db in
      try BinaryContentRecord.fetchAll(db)
    }
    let imageTuples = binaryContentRecords.compactMap { record -> (ScopedKey, Value) in
      return (ScopedKey(scope: record.noteId, key: record.key), .blob(mimeType: record.mimeType, blob: record.blob))
    }
    try crdt.bulkWrite(Dictionary(imageTuples, uniquingKeysWith: { value, _ in value }))

    let studyLogEntries = try dbQueue.read { db in
      try StudyLogEntryRecord.fetchAll(db)
    }
    let bulkEntries = try studyLogEntries.map { entry -> (ScopedKey, Value) in
      let scope = "note=\(entry.noteId).prompt=\(entry.promptKey)"
      let formattedTime = ISO8601DateFormatter().string(from: entry.timestamp)
      let key = "\(formattedTime).\(UUID().uuidString)"
      let sle = StudyLogEntry(entry)
      let data = try encoder.encode(sle)
      let json = String(data: data, encoding: .utf8)!
      return (ScopedKey(scope: scope, key: key), .json(json))
    }
    try crdt.bulkWrite(Dictionary(uniqueKeysWithValues: bulkEntries))
    crdtDocument.save(to: fileURL, for: .forCreating, completionHandler: nil)
  }

  /// Merges new content from another storage container into this storage container.
  public func merge(other: LegacyNoteDatabase) throws -> MergeResult {
    guard let localQueue = dbQueue, let remoteQueue = other.dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
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
          Self.backupDatabases(inMemoryDb: dbQueue, onDiskDb: conflictQueue)
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
    let diskDbQueue = try memoryDatabaseQueue(fileURL: url)
    DispatchQueue.main.async {
      if let inMemoryQueue = self.dbQueue {
        if diskDbQueue.deviceVersionVector == inMemoryQueue.deviceVersionVector {
          Logger.shared.info("UIDocument: On-disk content is the same as memory; ignoring")
        } else if diskDbQueue.deviceVersionVector > inMemoryQueue.deviceVersionVector {
          Logger.shared.info("UIDocument: On-disk data is strictly greater than in-memory; overwriting")
          self.dbQueue = diskDbQueue
        } else {
          Logger.shared.info("UIDocument: **Merging** disk contents with memory.\nDisk: \(diskDbQueue.deviceVersionVector)\nMemory: \(inMemoryQueue.deviceVersionVector)")
          // Make a backup of the two databases for future debugging if needed
          Self.backupDatabases(inMemoryDb: inMemoryQueue, onDiskDb: diskDbQueue)
          do {
            let result = try inMemoryQueue.merge(remoteQueue: diskDbQueue)
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
        self.dbQueue = diskDbQueue
      }
    }
  }

  private static func backupDatabases(inMemoryDb: DatabaseQueue, onDiskDb: DatabaseQueue) {
    // swiftlint:disable:next force_try
    let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let mergeDirectoryURL = documentsDirectoryURL.appendingPathComponent("merge-attempts")
    let creationDate = Date()
    let unwantedCharacters = CharacterSet(charactersIn: "-:")
    var uniqifier = ISO8601DateFormatter().string(from: creationDate)
    uniqifier.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })

    let containerURL = mergeDirectoryURL.appendingPathComponent("merge-\(uniqifier)")
    do {
      Logger.shared.info("Making a backup to \(containerURL)")
      try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
      let inMemoryURL = containerURL.appendingPathComponent("memory.sqlite")
      try inMemoryDb.writeWithoutTransaction { db in
        try db.execute(sql: "VACUUM INTO '\(inMemoryURL.path)'")
      }
      let onDiskURL = containerURL.appendingPathComponent("disk.sqlite")
      try onDiskDb.writeWithoutTransaction { db in
        try db.execute(sql: "VACUUM INTO '\(onDiskURL.path)'")
      }
    } catch {
      Logger.shared.error("Unexpected error making backup: \(error)")
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
    Logger.shared.info("UIDocument \(documentState): Writing content to '\(url.path)'")
    try dbQueue.writeWithoutTransaction { db in
      try db.execute(sql: "VACUUM INTO '\(url.path)'")
    }
  }

  public func flush() throws {
    save(to: fileURL, for: .forOverwriting, completionHandler: nil)
  }

  public var allMetadata: [Note.Identifier: NoteMetadataRecord] = [:] {
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
      throw NoteDatabaseError.databaseIsNotOpen
    }
    let identifier = UUID().uuidString
    try dbQueue.write { db in
      let updateKey = try updateIdentifier(in: db)
      try note.save(identifier: identifier, updateKey: updateKey, to: db)
      Logger.shared.info("Created new note \(identifier)")
    }
    return identifier
  }

  /// Updates a note.
  /// - parameter noteIdentifier: The identifier of the note to update.
  /// - parameter updateBlock: A block that receives the current value of the note and returns the updated value.
  public func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    try dbQueue.write { db in
      let existingNote = (try? Note(identifier: noteIdentifier, database: db)) ?? Note(markdown: "")
      let updatedNote = updateBlock(existingNote)
      let updateKey = try updateIdentifier(in: db)
      try updatedNote.save(identifier: noteIdentifier, updateKey: updateKey, to: db)
    }
  }

  public func bulkCreateNotes(_ notes: [Note]) throws {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    try dbQueue.write { db in
      let updateKey = try updateIdentifier(in: db)
      for note in notes {
        let identifier = UUID().uuidString
        try note.save(identifier: identifier, updateKey: updateKey, to: db)
      }
      Logger.shared.info("Finished bulk import of \(notes.count) note(s)")
    }
  }

  public func bulkImportBooks(_ booksAndImages: [BookAndImage], hashtags: String) throws {
    try bulkUpdate(updateBlock: { db, updateIdentifier in
      for bookAndImage in booksAndImages {
        let identifier = UUID().uuidString
        var note = Note(bookAndImage, hashtags: hashtags)
        let noteTimestamp = bookAndImage.book.dateAdded ?? Date()
        note.metadata.creationTimestamp = noteTimestamp
        note.metadata.modifiedTimestamp = noteTimestamp
        note.metadata.book = bookAndImage.book
        try note.save(identifier: identifier, updateKey: updateIdentifier, to: db)
        if let typedData = bookAndImage.image {
          let binaryRecord = BinaryContentRecord(
            blob: typedData.data,
            noteId: identifier,
            key: Note.coverImageKey,
            role: "embeddedImage",
            mimeType: typedData.type.preferredMIMEType ?? "application/octet-stream"
          )
          try binaryRecord.save(db)
        }
      }
    })
  }

  private func bulkUpdate(updateBlock: (Database, UpdateIdentifier) throws -> Void) throws {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    try dbQueue.write { db in
      let updateKey = try updateIdentifier(in: db)
      try updateBlock(db, updateKey)
    }
  }

  public func search(for searchPattern: String) throws -> [Note.Identifier] {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
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
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db -> Note in
      try Note(identifier: noteIdentifier, database: db)
    }
  }

  public func deleteNote(noteIdentifier: Note.Identifier) throws {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    _ = try dbQueue.write { db in
      let updateKey = try self.updateIdentifier(in: db)
      try deleteNote(noteIdentifier: noteIdentifier, updateKey: updateKey, database: db)
    }
  }

  public func deleteNote(noteIdentifier: Note.Identifier, updateKey: UpdateIdentifier, database db: Database) throws {
    guard var note = try NoteRecord.filter(key: noteIdentifier).fetchOne(db) else {
      return
    }
    let updateKey = try self.updateIdentifier(in: db)
    try note.contentRecords.deleteAll(db)
    note.deleted = true
    note.modifiedDevice = updateKey.deviceID
    note.modifiedTimestamp = Date()
    note.updateSequenceNumber = updateKey.updateSequenceNumber
    try note.update(db)
  }

  public func eligiblePromptIdentifiers(
    before date: Date,
    limitedTo noteIdentifier: Note.Identifier?
  ) throws -> [PromptIdentifier] {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      let promptStatisticsRequest: QueryInterfaceRequest<PromptRecord>
      if let noteIdentifier = noteIdentifier {
        guard let note = try NoteRecord.fetchOne(db, key: noteIdentifier) else {
          throw NoteDatabaseError.noSuchNote
        }
        promptStatisticsRequest = note.promptStatistics
      } else {
        promptStatisticsRequest = PromptRecord.all()
      }
      let records = try promptStatisticsRequest
        .filter(PromptRecord.Columns.due == nil || PromptRecord.Columns.due <= date)
        .fetchAll(db)
      return records.map {
        PromptIdentifier(noteId: $0.noteId, promptKey: $0.promptKey, promptIndex: Int($0.promptIndex))
      }
    }
  }

  public func prompt(
    promptIdentifier: PromptIdentifier
  ) throws -> Prompt {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      let identifier = ContentIdentifier(noteId: promptIdentifier.noteId, key: promptIdentifier.promptKey)
      let promptCollection = try Self.promptCollection(identifier: identifier, database: db)
      return promptCollection.prompts[Int(promptIdentifier.promptIndex)]
    }
  }

  internal func countOfContentRecords() throws -> Int {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      try ContentRecord.fetchCount(db)
    }
  }

  public func data<S>(for fileWrapperKey: S) throws -> Data? where S: StringProtocol {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      guard let asset = try AssetRecord.fetchOne(db, key: String(fileWrapperKey)) else {
        throw NoteDatabaseError.noSuchAsset
      }
      return asset.data
    }
  }

  public func recordStudyEntry(_ entry: StudyLog.Entry, buryRelatedPrompts: Bool) throws {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
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
      let updateKey = try self.updateIdentifier(in: db)
      try Self.updatePrompt(entry.identifier, for: record, in: db, buryRelatedPrompts: buryRelatedPrompts, updateKey: updateKey)
    }
    notesDidChangeSubject.send()
  }

  private static func updatePrompt(
    _ identifier: PromptIdentifier,
    for entry: StudyLogEntryRecord,
    in db: Database,
    buryRelatedPrompts: Bool,
    updateKey: UpdateIdentifier
  ) throws {
    var prompt = try PromptRecord.fetchOne(db, key: identifier)!
    let delay: TimeInterval
    if let lastReview = prompt.lastReview, let idealInterval = prompt.idealInterval {
      let idealDate = lastReview.addingTimeInterval(idealInterval)
      delay = max(entry.timestamp.timeIntervalSince(idealDate), 0)
    } else {
      delay = 0
    }
    let outcome = try prompt.item.updating(with: Self.scheduler, recallEase: entry.cardAnswer, timeIntervalSincePriorReview: delay)

    prompt.applyItem(outcome, on: entry.timestamp, updateKey: updateKey)
    prompt.totalCorrect += entry.correct
    prompt.totalIncorrect += entry.incorrect
    try prompt.update(db)

    if buryRelatedPrompts {
      let minimumDue = entry.timestamp.addingTimeInterval(.day)
      let updates = try PromptRecord
        .filter(PromptRecord.Columns.noteId == identifier.noteId && PromptRecord.Columns.promptKey == identifier.promptKey &&
          (PromptRecord.Columns.due == nil || PromptRecord.Columns.due < minimumDue)
        )
        .updateAll(db, [
          PromptRecord.Columns.due.set(to: minimumDue),
          PromptRecord.Columns.modifiedDevice.set(to: updateKey.deviceID),
          PromptRecord.Columns.updateSequenceNumber.set(to: updateKey.updateSequenceNumber),
        ])
      Logger.shared.info("Buried \(updates) prompts(s)")
    }
  }

  public var studyLog: StudyLog {
    var log = StudyLog()
    do {
      guard let dbQueue = dbQueue else {
        throw NoteDatabaseError.databaseIsNotOpen
      }
      let entries = try dbQueue.read { db -> [StudyLogEntryInfo] in
        let request = StudyLogEntryRecord
          .order(StudyLogEntryRecord.Columns.timestamp)
          .including(required: StudyLogEntryRecord.prompt)
        return try StudyLogEntryInfo
          .fetchAll(db, request)
      }
      entries
        .map {
          StudyLog.Entry(
            timestamp: $0.promptHistory.timestamp,
            identifier: PromptIdentifier(
              noteId: $0.promptHistory.noteId,
              promptKey: $0.promptHistory.promptKey,
              promptIndex: $0.promptHistory.promptIndex
            ),
            statistics: AnswerStatistics(
              correct: $0.promptHistory.correct,
              incorrect: $0.promptHistory.incorrect
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
  /// - parameter filter: An optional filter closure to determine if the page's prompts should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining prompt eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  public func studySession(
    filter: ((Note.Identifier, NoteMetadataRecord) -> Bool)? = nil,
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
    filter: ((Note.Identifier, NoteMetadataRecord) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    return allMetadata
      .filter { filter($0.key, $0.value) }
      .map { (name, reviewProperties) -> StudySession in
        let promptIdentifiers = try? eligiblePromptIdentifiers(before: date, limitedTo: name)
        return StudySession(
          promptIdentifiers ?? [],
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
  public func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedPrompts: Bool) throws {
    let entries = studySession.results.map { tuple -> StudyLog.Entry in
      StudyLog.Entry(timestamp: date, identifier: tuple.key, statistics: tuple.value)
    }
    for entry in entries {
      try recordStudyEntry(entry, buryRelatedPrompts: buryRelatedPrompts)
    }
  }

  /// All hashtags used across all pages, sorted.
  public var hashtags: [String] {
    let hashtags = allMetadata.values
      .filter { $0.folder == nil }
      .reduce(into: Set<String>()) { hashtags, props in
        hashtags.formUnion(props.noteLinks.map { $0.targetTitle })
      }
    return Array(hashtags).sorted()
  }

  /// All folders across all pages, sorted.
  public var folders: [String] {
    var folders = Set<String>()
    for noteMetadata in allMetadata.values {
      if let folder = noteMetadata.folder {
        folders.insert(folder)
      }
    }
    return Array(folders).sorted()
  }

  public func promptCollectionPublisher(promptType: PromptType, tagged tag: String?) -> AnyPublisher<[ContentIdentifier], Error> {
    guard let dbQueue = dbQueue else {
      return Fail<[ContentIdentifier], Swift.Error>(error: NoteDatabaseError.databaseIsNotOpen).eraseToAnyPublisher()
    }
    return ValueObservation.tracking { db -> [ContentIdentifier] in
      var baseRequest = ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .joining(required: ContentRecord.note.filter(NoteRecord.Columns.folder == nil || NoteRecord.Columns.folder != PredefinedFolder.recentlyDeleted.rawValue))
      if let tag = tag {
        baseRequest = baseRequest
          .joining(required: ContentRecord.note.including(required: NoteRecord.noteHashtags.filter(NoteLinkRecord.Columns.targetTitle.like("\(tag)/%") || NoteLinkRecord.Columns.targetTitle.like("\(tag)"))))
      }
      return try baseRequest.asRequest(of: ContentIdentifier.self).fetchAll(db)
    }.publisher(in: dbQueue).eraseToAnyPublisher()
  }

  public func attributedQuotes(for contentIdentifiers: [ContentIdentifier]) throws -> [AttributedQuote] {
    guard let dbQueue = dbQueue else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      return try ContentRecord
        .filter(keys: contentIdentifiers.map { $0.keyArray })
        .including(required: ContentRecord.note.including(all: NoteRecord.binaryContentRecords.filter(BinaryContentRecord.Columns.role == ContentRole.embeddedImage.rawValue).forKey("thumbnailImage")))
        .asRequest(of: AttributedQuote.self)
        .fetchAll(db)
    }
  }

  public var bookMetadata: [String: BookNoteMetadata] {
    get throws {
      guard let dbQueue = dbQueue else {
        throw NoteDatabaseError.databaseIsNotOpen
      }
      return try dbQueue.read { db in
        try NoteMetadataRecord.request().fetchAll(db)
          .dictionaryMap { (key: $0.id, value: BookNoteMetadata($0)) }
      }
    }
  }

  public func bookMetadataPublisher() -> AnyPublisher<[String: BookNoteMetadata], Error> {
    return ValueObservation.tracking { db in
      try NoteMetadataRecord.request().fetchAll(db)
    }
    .publisher(in: dbQueue!)
    .map { records in
      records.dictionaryMap { (key: $0.id, value: BookNoteMetadata($0)) }
    }
    .eraseToAnyPublisher()
  }

  public func coverImage(bookID: String, maxSize: CGFloat) -> UIImage? {
    return try? dbQueue?.read({ db in
      let record = try BinaryContentRecord
        .filter(key: [BinaryContentRecord.Columns.noteId.rawValue: bookID, BinaryContentRecord.Columns.key.rawValue: "coverImage"])
        .fetchOne(db)
      return record?.blob.image(maxSize: maxSize)
    })
  }
}

// MARK: - Internal (to enable dividing into extensions)

internal extension LegacyNoteDatabase {
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
      NoteLinkRecord.all(),
      PromptRecord.all(),
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
      throw NoteDatabaseError.databaseIsNotOpen
    }
    return try dbQueue.write { db in
      try currentDeviceRecord(in: db)
    }
  }

  /// Given an open database connection, returns the device record for the current device.
  func currentDeviceRecord(in db: Database) throws -> DeviceRecord {
    guard let uuid = device.identifierForVendor?.uuidString else {
      throw NoteDatabaseError.noDeviceUUID
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
      throw NoteDatabaseError.noDeviceUUID
    }
    try db.execute(sql: "INSERT INTO device (uuid, name) VALUES (?, ?)", arguments: [uuid, device.name])
    return db.lastInsertedRowID
  }

  func updateIdentifier(
    in database: Database
  ) throws -> UpdateIdentifier {
    var device = try currentDeviceRecord(in: database)
    device.updateSequenceNumber += 1
    try device.update(database)
    return UpdateIdentifier(deviceID: device.uuid, updateSequenceNumber: device.updateSequenceNumber)
  }

  static func fetchAllMetadata(from db: Database) throws -> [Note.Identifier: NoteMetadataRecord] {
    let metadata = try NoteMetadataRecord.request().fetchAll(db)
    let tuples = metadata.map { metadataItem -> (key: Note.Identifier, value: NoteMetadataRecord) in
      (key: metadataItem.id, value: metadataItem)
    }
    return Dictionary(uniqueKeysWithValues: tuples)
  }

  static func promptCollection(identifier: ContentIdentifier, database: Database) throws -> PromptCollection {
    guard let record = try ContentRecord.fetchOne(database, key: [ContentRecord.Columns.noteId.rawValue: identifier.noteId, ContentRecord.Columns.key.rawValue: identifier.key]) else {
      throw NoteDatabaseError.unknownPromptCollection
    }
    return try record.asPromptCollection()
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
      try database.rebuildFullTextIndex()
    })
    try migrator.registerMigrationScript(.changeContentKey, additionalSteps: { database in
      try database.rebuildFullTextIndex()
    })
    try migrator.registerMigrationScript(.prompts)
    try migrator.registerMigrationScript(.promptTable)
    try migrator.registerMigrationScript(.links)
    try migrator.registerMigrationScript(.binaryContent)
    try migrator.registerMigrationScript(.creationTimestamp)
    try migrator.registerMigrationScript(.addFolders)
    migrator.registerMigration("addSummary", migrate: { database in
      try database.alter(table: "note", body: { table in
        table.add(column: "summary", .text)
      })
    })

    let priorMigrations = try databaseQueue.read(migrator.appliedMigrations)
    try migrator.migrate(databaseQueue)
    let postMigrations = try databaseQueue.read(migrator.appliedMigrations)
    return Set(priorMigrations) != Set(postMigrations)
  }
}

private extension PromptRecord {
  var item: PromptSchedulingMetadata {
    if let due = due, let lastReview = lastReview {
      let interval = due.timeIntervalSince(lastReview)
      assert(interval > 0)
      return PromptSchedulingMetadata(
        mode: .review,
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? .day,
        reviewSpacingFactor: spacedRepetitionFactor
      )
    } else {
      // Create an item that's *just about to graduate* if we've never seen it before.
      // That's because we make new items due "last learning interval" after creation
      return PromptSchedulingMetadata(
        mode: .learning(step: SchedulingParameters.standard.learningIntervals.count),
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? 0,
        reviewSpacingFactor: spacedRepetitionFactor
      )
    }
  }

  mutating func applyItem(_ item: PromptSchedulingMetadata, on date: Date, updateKey: UpdateIdentifier) {
    reviewCount = item.reviewCount
    lapseCount = item.lapseCount
    spacedRepetitionFactor = item.reviewSpacingFactor
    lastReview = date
    idealInterval = item.interval
    due = date.addingTimeInterval(item.interval.fuzzed())
    timestamp = date
    modifiedDevice = updateKey.deviceID
    updateSequenceNumber = updateKey.updateSequenceNumber
  }
}

private extension StudyLogEntryRecord {
  var cardAnswer: RecallEase {
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

  func rebuildFullTextIndex() throws {
    try drop(table: "noteFullText")
    try create(virtualTable: "noteFullText", using: FTS5()) { table in
      table.synchronize(withTable: "content")
      table.column("text")
      table.tokenizer = .porter(wrapping: .unicode61())
    }
  }
}

private extension DatabaseQueue {
  var deviceVersionVector: VersionVector {
    do {
      return try read { db in
        let devices = (try? DeviceRecord.fetchAll(db)) ?? []
        return VersionVector(devices)
      }
    } catch {
      Logger.shared.error("Unexpected error getting device version vector: \(error)")
      return VersionVector([])
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
          recordType: PromptRecord.MergeInfo.self,
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
    let bundle = Bundle(for: LegacyNoteDatabase.self)
    guard
      let scriptURL = bundle.url(forResource: migration.rawValue, withExtension: "sql"),
      let script = try? String(contentsOf: scriptURL)
    else {
      throw NoteDatabaseError.missingMigrationScript
    }
    registerMigration(migration.rawValue) { database in
      try database.execute(sql: script)
      try additionalSteps?(database)
    }
  }
}

extension SchedulingParameters {
  public static let standard = SchedulingParameters(
    learningIntervals: [.day, 4 * .day],
    goodGraduatingInterval: 7 * .day
  )
}

extension Sequence {
  /// Returns an dictionary containing the results of mapping the given closure over the sequence’s elements.
  ///
  /// - parameter mapping: A closure that maps an `Element` into a (`Key`, `Value`) pair.
  /// - parameter uniqingKeysWith: If `mapping` returns two items with the same key, this closure determines which one to keep in the dictionary.
  /// - returns: A dictionary mapping keys to values.
  func dictionaryMap<Key: Hashable, Value: Any>(
    mapping: (Element) throws -> (key: Key, value: Value),
    uniquingKeysWith: (Value, Value) -> Value = { _, value in value }
  ) rethrows -> [Key: Value] {
    let tuples = try map(mapping)
    return Dictionary(tuples, uniquingKeysWith: uniquingKeysWith)
  }

  /// Returns an dictionary containing the results of mapping the given closure over the sequence’s elements.
  ///
  /// - parameter mapping: A closure that maps an `Element` into a (`Key`, `Value`) pair.
  /// - parameter uniqingKeysWith: If `mapping` returns two items with the same key, this closure determines which one to keep in the dictionary.
  /// - returns: A dictionary mapping keys to values.
  func dictionaryCompactMap<Key: Hashable, Value: Any>(
    mapping: (Element) throws -> (key: Key, value: Value)?,
    uniquingKeysWith: (Value, Value) -> Value = { _, value in value }
  ) rethrows -> [Key: Value] {
    let tuples = try compactMap(mapping)
    return Dictionary(tuples, uniquingKeysWith: uniquingKeysWith)
  }
}
