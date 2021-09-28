// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Foundation
import GRDB
import KeyValueCRDT
import Logging
import os
import SpacedRepetitionScheduler
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

private extension Logging.Logger {
  static let keyValueNoteDatabase: Logging.Logger = {
    var logger = Logger(label: "org.brians-brain.KeyValueNoteDatabase")
    logger.logLevel = .debug
    return logger
  }()
}

enum KeyValueNoteDatabaseScope: String {
  case studyLog = ".studyLog"
}

/// Errors specific to the ``NoteDatabase`` protocol.
public enum NoteDatabaseError: String, Swift.Error {
  case cannotDecodePromptCollection = "Cannot decode the prompt collection."
  case databaseAlreadyOpen = "The database is already open."
  case databaseIsNotOpen = "The database is not open."
  case noDeviceUUID = "Could not get the device UUID."
  case noSuchAsset = "The specified asset does not exist."
  case noSuchPrompt = "The specified prompt does not exist."
  case noSuchNote = "The specified note does not exist."
  case notWriteable = "The database is not currently writeable."
  case unknownPromptCollection = "The prompt collection does not exist."
  case unknownPromptType = "The prompt uses an unknown type."
  case missingMigrationScript = "Could not find a required migration script."
  case unexpectedNoteContent = "Note keys did not match the expected structure."
}

private extension DatabaseFunction {
  /// A custom function that returns the family name before other name components to allow name sorting.
  static let nameSort = DatabaseFunction("name_sort", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    // Extract string value, if any...
    guard let string = String.fromDatabaseValue(values[0]), let components = try? PersonNameComponents(string) else {
      return nil
    }

    // TODO: PersonNameComponents does not properly parse "T. S. Eliot" -- special case abbreviated names
    return [components.familyName, components.givenName, components.middleName]
      .compactMap { $0 }
      .joined(separator: " ")
  }
}

/// An implementation of ``NoteDatabase`` based upon ``UIKeyValueDocument``
public final class NoteDatabase {
  public typealias IOCompletionHandler = (Bool) -> Void

  /// Initializes and opens the database stored at `fileURL`
  @MainActor
  public init(fileURL: URL, authorDescription: String) async throws {
    var config = Configuration()
    config.prepareDatabase { db in
      db.add(function: .nameSort)
    }
    self.keyValueDocument = try UIKeyValueDocument(
      fileURL: fileURL,
      authorDescription: authorDescription,
      configuration: config
    )
    guard await keyValueDocument.open(), let keyValueCRDT = keyValueDocument.keyValueCRDT else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    self.keyValueCRDT = keyValueCRDT
    self.instanceID = keyValueCRDT.instanceID
    keyValueDocument.delegate = self
    self.allTagsInvalidationSubscription = notesDidChange.sink { [weak self] _ in
      self?.cachedAllTags = nil
    }
    self.allTagsInvalidationSubscription = keyValueCRDT
      .readPublisher(key: NoteDatabaseKey.metadata.rawValue)
      .sink(receiveCompletion: { error in
        Logger.shared.error("Error maintaining cache: \(error)")
      }, receiveValue: { [weak self] update in
        guard let self = self else { return }
        for scopedKey in update.keys {
          self.cachedBookMetadata[scopedKey.scope] = nil
        }
      })
  }

  public static var coverImageKey: String { NoteDatabaseKey.coverImage.rawValue }

  private let keyValueDocument: UIKeyValueDocument

  /// The `KeyValueDatabase` contained in `keyValueDocument`
  private let keyValueCRDT: KeyValueDatabase

  public var fileURL: URL { keyValueDocument.fileURL }

  public let instanceID: UUID

  public var documentState: UIDocument.State { keyValueDocument.documentState }

  public var hasUnsavedChanges: Bool { keyValueDocument.hasUnsavedChanges }

  public func close() async -> Bool {
    await keyValueDocument.close()
  }

  public func save(to url: URL, for saveOperation: UIDocument.SaveOperation) async -> Bool {
    await keyValueDocument.save(to: url, for: saveOperation)
  }

  public func refresh() throws {
    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
  }

  public func flush() async throws {
    await keyValueDocument.save(to: fileURL, for: .forOverwriting)
  }

  public func merge(other: NoteDatabase) throws {
    guard let keyValueCRDT = keyValueDocument.keyValueCRDT, let otherKeyValueCRDT = other.keyValueDocument.keyValueCRDT else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    try keyValueCRDT.merge(source: otherKeyValueCRDT)
  }

  public var notesDidChange: AnyPublisher<Void, Never> {
    keyValueCRDT
      .didChangePublisher()
      .map { _ in () } // turn any value to a Void
      .catch { _ in Just<Void>(()) }
      .eraseToAnyPublisher()
  }

  private var allTagsInvalidationSubscription: AnyCancellable?
  private var cachedAllTags: [String]?

  public var allTags: [String] {
    get throws {
      if let cachedAllTags = cachedAllTags {
        return cachedAllTags
      } else {
        let tags = try keyValueCRDT.read { database in
          try TagsRecord.allTags(in: database)
        }
        let tagsArray = Array(tags).sorted()
        cachedAllTags = tagsArray
        return tagsArray
      }
    }
  }

  // TODO: Exclude notes in the trash? Currently used only in tests so :shrug:
  /// Gets the number of notes in the database
  public var noteCount: Int {
    do {
      return try keyValueCRDT.keys(key: NoteDatabaseKey.metadata.rawValue).count
    } catch {
      Logger.shared.error("Unexpected error getting note count: \(error)")
      return 0
    }
  }

  private var cachedBookMetadataInvalidation: AnyCancellable?
  private var cachedBookMetadata: [Note.Identifier: BookNoteMetadata] = [:]

  public func bookMetadata(identifier: Note.Identifier) -> BookNoteMetadata? {
    if let cachedResult = cachedBookMetadata[identifier] {
      return cachedResult
    }
    do {
      let value = try keyValueCRDT.read(key: NoteDatabaseKey.metadata.rawValue, scope: identifier).resolved(with: .lastWriterWins)?.decodeJSON(BookNoteMetadata.self)
      cachedBookMetadata[identifier] = value
      return value
    } catch {
      Logger.shared.error("Unexpected error getting metadata for \(identifier): \(error)")
      return nil
    }
  }

  func noteIdentifiers(
    structureIdentifier: NotebookStructureViewController.StructureIdentifier,
    sortOrder: BookCollectionViewSnapshotBuilder.SortOrder
  ) throws -> [Note.Identifier] {
    let sqlLiteral = NoteIdentifierRecord.sqlLiteral(structureIdentifier: structureIdentifier, sortOrder: sortOrder)
    let records = try keyValueCRDT.read { db -> [NoteIdentifierRecord] in
      let (sql, arguments) = try sqlLiteral.build(db)
      return try NoteIdentifierRecord.fetchAll(db, sql: sql, arguments: arguments)
    }
    return records.map { $0.scope }
  }

  public func readPublisher(noteIdentifier: Note.Identifier, key: NoteDatabaseKey) -> AnyPublisher<[NoteDatabaseKey: [Version]], Error> {
    keyValueCRDT
      .readPublisher(scope: noteIdentifier, key: key.rawValue)
      .map { scopedKeyDictionary in
        assert(scopedKeyDictionary.count < 2)
        return scopedKeyDictionary.dictionaryMap(mapping: { (NoteDatabaseKey(rawValue: $0.key.key), $0.value) })
      }
      .eraseToAnyPublisher()
  }

  /// Publishes individual key/value updates to the database.
  public var updatedValuesPublisher: AnyPublisher<(ScopedKey, [Version]), Never> {
    keyValueCRDT.updatedValuesPublisher
  }

  public func createNote(_ note: Note) throws -> Note.Identifier {
    let noteID = UUID().uuidString
    let existingContent = NoteUpdatePayload(noteIdentifier: noteID)
    try saveBookNote(note, existingContent: existingContent)
    Logger.keyValueNoteDatabase.info("Created note \(noteID)")
    return noteID
  }

  public func note(noteIdentifier: Note.Identifier) throws -> Note {
    let onDiskContents = try keyValueCRDT.bulkRead(scope: noteIdentifier)
    Logger.keyValueNoteDatabase.info("Trying to read note \(noteIdentifier). Found \(onDiskContents.count) records.")
    guard let payload = try NoteUpdatePayload(onDiskContents: onDiskContents), let note = try payload.asNote() else {
      Logger.keyValueNoteDatabase.error("Could not convert on-disk contents into a note")
      throw NoteDatabaseError.noSuchNote
    }
    return note
  }

  public func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws {
    let onDiskContents = try keyValueCRDT.bulkRead(scope: noteIdentifier)
    let payload = try NoteUpdatePayload(onDiskContents: onDiskContents) ?? NoteUpdatePayload(noteIdentifier: noteIdentifier)
    let initialNote = try payload.asNote() ?? Note(markdown: "")
    let updatedNote = updateBlock(initialNote)
    try saveBookNote(updatedNote, existingContent: payload)
  }

  public func deleteNote(noteIdentifier: Note.Identifier) throws {
    let updates = try keyValueCRDT.keys(scope: noteIdentifier).dictionaryMap {
      (key: $0, value: Value.null)
    }
    try keyValueCRDT.bulkWrite(updates)
  }

  /// Reads a value from the database.
  /// - Parameters:
  ///   - noteIdentifier: The note holding the value.
  ///   - key: The key associated with the value.
  /// - Returns: An array of value versions. Normally this will have zero or one value. However, if there are update conflicts from multiple authors, the result array may have more than one value.
  public func read(noteIdentifier: Note.Identifier, key: NoteDatabaseKey) throws -> [Version] {
    try keyValueCRDT.read(key: key.rawValue, scope: noteIdentifier)
  }

  /// Writes a value to the database.
  /// - Parameters:
  ///   - value: The value to write.
  ///   - noteIdentifier: The note holding the value.
  ///   - key: The key associated with the value.
  public func writeValue(_ value: Value, noteIdentifier: Note.Identifier, key: NoteDatabaseKey) throws {
    try keyValueCRDT.bulkWrite([ScopedKey(scope: noteIdentifier, key: key.rawValue): value])
  }

  /// Bulk read of keys from the database.
  /// - parameter isIncluded: A closure that determines if the value is included in the results.
  /// - returns: A mapping of `ScopedKey` to `[Version]`, where each entry in `[Version]` is a value written by a single author to that key.
  public func bulkRead(isIncluded: (String, String) -> Bool) throws -> [ScopedKey: [Version]] {
    try keyValueCRDT.bulkRead(isIncluded: isIncluded)
  }

  public func bulkImportBooks(_ booksAndImages: [BookAndImage], hashtags: String) throws {
    try keyValueCRDT.write { db in
      for bookAndImage in booksAndImages {
        var payload = NoteUpdatePayload(noteIdentifier: UUID().uuidString)
        let bookAddedDate = bookAndImage.book.dateAdded ?? Date()
        var metadata = BookNoteMetadata(
          title: bookAndImage.book.title,
          creationTimestamp: bookAddedDate,
          modifiedTimestamp: bookAddedDate
        )
        metadata.book = bookAndImage.book
        if let dateAdded = bookAndImage.book.dateAdded {
          // Assume we read the book
          let components = Calendar.current.dateComponents([.year, .month, .day], from: dateAdded)
          var readingHistory = ReadingHistory()
          readingHistory.finishReading(finishDate: components)
          metadata.book?.readingHistory = readingHistory
        }
        metadata.tags = hashtags.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        payload.insert(key: .metadata, value: try Value(metadata))
        payload.insert(key: .bookIndex, value: Value(metadata.indexedContents))
        if let review = bookAndImage.book.review {
          payload.insert(key: .noteText, value: .text(review))
        }
        if let imageData = bookAndImage.image {
          payload.insert(key: .coverImage, value: .blob(mimeType: imageData.type.preferredMIMEType ?? "application/octet-stream", blob: imageData.data))
        }
        try keyValueCRDT.bulkWrite(database: db, values: payload.asKeyValueCRDTUpdates())
      }
    }
  }

  public func search(for searchPattern: String) throws -> [Note.Identifier] {
    let scopedKeys = try keyValueCRDT.searchText(for: searchPattern)
    let uniqueIdentifiers = scopedKeys
      .map { $0.scope }
      .asSet()
    return Array(uniqueIdentifiers)
  }

  public func eligiblePromptIdentifiers(
    before date: Date,
    limitedTo noteIdentifier: Note.Identifier?
  ) throws -> [PromptIdentifier] {
    let results: [ScopedKey: [Version]]
    do {
      results = try keyValueCRDT.bulkRead(isIncluded: { scope, key -> Bool in
        if let noteIdentifier = noteIdentifier {
          if noteIdentifier != scope { return false }
        }
        return key.hasPrefix("prompt=") || key == NoteDatabaseKey.metadata.rawValue
      })
    } catch {
      Logger.keyValueNoteDatabase.error("Could not read prompt keys: \(error)")
      return []
    }
    var promptIdentifiers: [PromptIdentifier] = []
    for (scopedKey, versions) in results where scopedKey.key.starts(with: "prompt=") {
      guard
        let promptInfo = versions.resolved(with: .lastWriterWins)?.promptCollectionInfo
      else {
        continue
      }
      for (index, prompt) in promptInfo.promptStatistics.enumerated() where (prompt.due ?? .distantPast) <= date {
        promptIdentifiers.append(PromptIdentifier(noteId: scopedKey.scope, promptKey: scopedKey.key, promptIndex: index))
      }
    }
    return promptIdentifiers
  }

  public func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedPrompts: Bool) throws {
    let scopedKeysToFetch = studySession.results.keys.map { ScopedKey(scope: $0.noteId, key: $0.promptKey) }
    let promptInfo = try keyValueCRDT
      .bulkRead(keys: scopedKeysToFetch.map { $0.key })
      .dictionaryCompactMap(mapping: { scopedKey, versions -> (key: ScopedKey, value: PromptCollectionInfo)? in
        guard let info = versions.promptCollectionInfo else { return nil }
        return (key: scopedKey, value: info)
      })
    Logger.keyValueNoteDatabase.debug("Fetched \(promptInfo.count) collections for update")

    var updates: [ScopedKey: Value] = [:]
    for (promptIdentifier, answerStatistics) in studySession.results {
      // 1. Generate a StudyLog.Entry. Currently this is write-only; I never read these back. In theory one could reconstruct
      // the prompt scheduling information from them.
      let entry = StudyLog.Entry(timestamp: date, identifier: promptIdentifier, statistics: answerStatistics)
      // The scope is what ties this entry to its corresponding scope & key.
      let entryKey = ScopedKey(
        scope: KeyValueNoteDatabaseScope.studyLog.rawValue,
        key: NoteDatabaseKey.studyLogEntry(date: date, promptIdentifier: promptIdentifier, instanceID: instanceID).rawValue
      )
      updates[entryKey] = try Value(entry)

      // 2. Update the corresponding prompt info.
      let scopedKey = ScopedKey(scope: promptIdentifier.noteId, key: promptIdentifier.promptKey)
      if var info = promptInfo[scopedKey], promptIdentifier.promptIndex < info.promptStatistics.endIndex {
        var schedulingItem = info.promptStatistics[promptIdentifier.promptIndex].schedulingItem

        let delay: TimeInterval
        if let lastReview = info.promptStatistics[promptIdentifier.promptIndex].lastReview,
           let idealInterval = info.promptStatistics[promptIdentifier.promptIndex].idealInterval
        {
          let idealDate = lastReview.addingTimeInterval(idealInterval)
          delay = max(entry.timestamp.timeIntervalSince(idealDate), 0)
        } else {
          delay = 0
        }

        try schedulingItem.update(with: .standard, recallEase: schedulingItem.recallEase(for: entry), timeIntervalSincePriorReview: delay)
        info.promptStatistics[promptIdentifier.promptIndex].applySchedulingItem(schedulingItem, on: date)

        if buryRelatedPrompts {
          // All *other* prompts in this collection need to be scheduled out at least one day.
          let minimumDue = date.addingTimeInterval(.day)
          for index in info.promptStatistics.indices where index != promptIdentifier.promptIndex {
            if let existingDue = info.promptStatistics[index].due {
              info.promptStatistics[index].due = max(minimumDue, existingDue)
            } else {
              info.promptStatistics[index].due = minimumDue
            }
          }
        }
        updates[scopedKey] = try Value(info)
      } else {
        Logger.keyValueNoteDatabase.error("Could not find info or index for \(scopedKey)")
        assertionFailure()
      }
    }
    try keyValueCRDT.bulkWrite(updates)
  }

  public func prompt(promptIdentifier: PromptIdentifier) throws -> Prompt {
    guard let json = try keyValueCRDT.read(key: promptIdentifier.promptKey, scope: promptIdentifier.noteId).resolved(with: .lastWriterWins)?.json else {
      throw NoteDatabaseError.unknownPromptCollection
    }
    let promptInfo = try JSONDecoder.databaseDecoder.decode(PromptCollectionInfo.self, from: json.data(using: .utf8)!)
    guard let klass = PromptType.classMap[promptInfo.type], let collection = klass.init(rawValue: promptInfo.rawValue) else {
      throw NoteDatabaseError.unknownPromptType
    }
    return collection.prompts[promptIdentifier.promptIndex]
  }

  // TODO: This doesn't actually filter by tag
  public func promptCollectionPublisher(promptType: PromptType, tagged tag: String?) -> AnyPublisher<[ContentIdentifier], Error> {
    keyValueCRDT.readPublisher(keyPrefix: NoteDatabaseKey.promptPrefix(for: promptType))
      .map { results in
        results.map { scopedKey, _ in
          ContentIdentifier(noteId: scopedKey.scope, key: scopedKey.key)
        }
      }
      .eraseToAnyPublisher()
  }

  public func attributedQuotes(for contentIdentifiers: [ContentIdentifier]) throws -> [AttributedQuote] {
    let candidateNotes = contentIdentifiers.map { $0.noteId }.asSet()
    let candidateKeys = contentIdentifiers.map { $0.key }.asSet()
    let results = try keyValueCRDT.bulkRead(isIncluded: { scope, key in
      if candidateNotes.contains(scope), [NoteDatabaseKey.metadata.rawValue, NoteDatabaseKey.coverImage.rawValue].contains(key) {
        return true
      }
      return candidateKeys.contains(key)
    })
    return contentIdentifiers.compactMap { contentIdentifier -> AttributedQuote? in
      guard
        let versions = results[ScopedKey(scope: contentIdentifier.noteId, key: contentIdentifier.key)],
        let promptCollectionInfo = versions.resolved(with: .lastWriterWins)?.promptCollectionInfo,
        let quoteCollection = try? promptCollectionInfo.asPromptCollection()
      else {
        return nil
      }
      let metadata = results[ScopedKey(scope: contentIdentifier.noteId, key: NoteDatabaseKey.metadata.rawValue)]?
        .resolved(with: .lastWriterWins)?
        .bookNoteMetadata
      let thumbnailImage = results[ScopedKey(scope: contentIdentifier.noteId, key: NoteDatabaseKey.coverImage.rawValue)]?
        .resolved(with: .lastWriterWins)?
        .blob
      return AttributedQuote(
        noteId: contentIdentifier.noteId,
        key: contentIdentifier.key,
        text: quoteCollection.rawValue,
        title: metadata?.book?.title ?? metadata?.title ?? "",
        thumbnailImage: thumbnailImage
      )
    }
  }

  public func replaceText(_ originalText: String, with replacementText: String, filter: (BookNoteMetadata) -> Bool) throws {
    try keyValueCRDT.write { db in
      let metadataAndText = try keyValueCRDT.bulkRead(database: db, isIncluded: {
        [NoteDatabaseKey.metadata.rawValue, NoteDatabaseKey.noteText.rawValue].contains($1)
      })
      for (scopedKey, versions) in metadataAndText where scopedKey.key == NoteDatabaseKey.metadata.rawValue {
        guard
          let metadata = versions.resolved(with: .lastWriterWins)?.bookNoteMetadata,
          filter(metadata),
          let text = metadataAndText[ScopedKey(scope: scopedKey.scope, key: NoteDatabaseKey.noteText.rawValue)]?.resolved(with: .lastWriterWins)?.text
        else {
          continue
        }
        let updatedText = text.replacingOccurrences(of: originalText, with: replacementText)
        if updatedText != text {
          let onDiskContents = try keyValueCRDT.bulkRead(database: db, scope: scopedKey.scope)
          var payload = try NoteUpdatePayload(onDiskContents: onDiskContents)!
          if var note = try payload.asNote() {
            note.updateMarkdown(updatedText)
            try payload.update(with: note)
            try keyValueCRDT.bulkWrite(database: db, values: payload.asKeyValueCRDTUpdates())
          }
        }
      }
    }
  }

  public func renameHashtag(_ originalHashtag: String, to newHashtag: String, filter: (BookNoteMetadata) -> Bool) throws {
    try keyValueCRDT.write { db in
      let metadataAndText = try keyValueCRDT.bulkRead(database: db, isIncluded: {
        [NoteDatabaseKey.metadata.rawValue, NoteDatabaseKey.noteText.rawValue].contains($1)
      })
      for (scopedKey, versions) in metadataAndText where scopedKey.key == NoteDatabaseKey.metadata.rawValue {
        guard
          let metadata = versions.resolved(with: .lastWriterWins)?.bookNoteMetadata,
          filter(metadata),
          let text = metadataAndText[ScopedKey(scope: scopedKey.scope, key: NoteDatabaseKey.noteText.rawValue)]?.resolved(with: .lastWriterWins)?.text
        else {
          continue
        }

        let parsedText = ParsedString(text, grammar: MiniMarkdownGrammar.shared)
        guard let root = try? parsedText.result.get() else { continue }
        var replacementLocations = [Int]()
        root.forEach { node, startIndex, _ in
          guard node.type == .hashtag else { return }
          let range = NSRange(location: startIndex, length: node.length)
          let hashtag = String(utf16CodeUnits: parsedText[range], count: range.length)
          if originalHashtag.isPathPrefix(of: hashtag) {
            replacementLocations.append(startIndex)
          }
        }
        let originalHashtagLength = originalHashtag.utf16.count
        for location in replacementLocations.reversed() {
          parsedText.replaceCharacters(in: NSRange(location: location, length: originalHashtagLength), with: newHashtag)
        }

        let onDiskContents = try keyValueCRDT.bulkRead(database: db, scope: scopedKey.scope)
        var payload = try NoteUpdatePayload(onDiskContents: onDiskContents)!
        if var note = try payload.asNote() {
          note.updateMarkdown(parsedText.string)
          try payload.update(with: note)
          try keyValueCRDT.bulkWrite(database: db, values: payload.asKeyValueCRDTUpdates())
        }
      }
    }
  }

  public var studyLog: StudyLog {
    do {
      let records = try keyValueCRDT.bulkRead(scope: KeyValueNoteDatabaseScope.studyLog.rawValue)
      let entries = records.values.compactMap { versions -> StudyLog.Entry? in
        do {
          return try versions.studyLogEntry
        } catch {
          Logger.keyValueNoteDatabase.error("Unexpected error extracting a study log entry: \(error)")
          return nil
        }
      }
      return StudyLog(entries: entries)
    } catch {
      Logger.keyValueNoteDatabase.error("Unexpected error getting studyLog: \(error)")
      return StudyLog()
    }
  }
}

extension NoteDatabase: UIKeyValueDocumentDelegate {
  public func keyValueDocument(_ document: UIKeyValueDocument, willMergeCRDT sourceCRDT: KeyValueDatabase, into destinationCRDT: KeyValueDatabase) {
    do {
      let documentsDirectoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let mergeDirectoryURL = documentsDirectoryURL.appendingPathComponent("merge-attempts")
      let creationDate = Date()
      let unwantedCharacters = CharacterSet(charactersIn: "-:")
      var uniqifier = ISO8601DateFormatter().string(from: creationDate)
      uniqifier.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })

      let containerURL = mergeDirectoryURL.appendingPathComponent("merge-\(uniqifier)")
      Logger.shared.info("Making a backup to \(containerURL)")
      try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
      let inMemoryURL = containerURL.appendingPathComponent("memory.sqlite")
      try destinationCRDT.save(to: inMemoryURL)
      let onDiskURL = containerURL.appendingPathComponent("disk.sqlite")
      try sourceCRDT.save(to: onDiskURL)
    } catch {
      Logger.shared.error("Unexpected error making backup: \(error)")
    }
  }
}

private extension NoteDatabase {
  func saveBookNote(_ note: Note, existingContent: NoteUpdatePayload) throws {
    var existingContent = existingContent
    try existingContent.update(with: note)
    try keyValueCRDT.bulkWrite(existingContent.asKeyValueCRDTUpdates())
  }
}

struct NoteUpdatePayload {
  init(noteIdentifier: String) {
    self.noteIdentifier = noteIdentifier
  }

  /// Creates a payload with the on-disk contents of a single note.
  /// - precondition: The `scope` of each `ScopedKey` must be the same, and must be note identifier.
  /// - throws `NoteDatabaseError.unexpectedNoteContent` if the scopes do not match.
  init?(onDiskContents: [ScopedKey: [Version]]) throws {
    var noteIdentifier: String?
    for (scopedKey, versions) in onDiskContents {
      if noteIdentifier == nil {
        noteIdentifier = scopedKey.scope
      } else if noteIdentifier != scopedKey.scope {
        throw NoteDatabaseError.unexpectedNoteContent
      }
      updates[NoteDatabaseKey(rawValue: scopedKey.key)] = versions.resolved(with: .lastWriterWins)
    }
    if let noteIdentifier = noteIdentifier {
      self.noteIdentifier = noteIdentifier
    } else {
      return nil
    }
  }

  let noteIdentifier: String
  private var updates: [NoteDatabaseKey: Value] = [:]

  mutating func insert(key: NoteDatabaseKey, value: Value) {
    updates[key] = value
  }

  mutating func update(with note: Note) throws {
    updates[.metadata] = try Value(note.metadata)
    updates[.noteText] = Value(note.text)
    updates[.bookIndex] = Value(note.metadata.indexedContents)
    let unusedPromptKeys = Set(updates.keys.filter { $0.isPrompt }.map { $0.rawValue }).subtracting(note.promptCollections.keys)
    if !unusedPromptKeys.isEmpty {
      Logger.keyValueNoteDatabase.debug("Will remove unused prompt keys: \(unusedPromptKeys)")
    }
    for (promptKey, promptCollection) in note.promptCollections {
      Logger.keyValueNoteDatabase.debug("Updating prompt collection with key \(promptKey)")
      let key = NoteDatabaseKey(rawValue: promptKey)
      assert(key.isPrompt)
      if let promptCollectionValue = updates[key], var promptCollectionInfo = promptCollectionValue.promptCollectionInfo {
        promptCollectionInfo.rawValue = promptCollection.rawValue
        updates[key] = try Value(promptCollectionInfo)
      } else {
        updates[key] = try Value(PromptCollectionInfo(promptCollection))
      }
    }
    for unusedKey in unusedPromptKeys {
      let key = NoteDatabaseKey(rawValue: unusedKey)
      assert(key.isPrompt)
      updates[key] = .null
    }
  }

  func asKeyValueCRDTUpdates() -> [ScopedKey: Value] {
    updates
      .map { (key: ScopedKey(scope: noteIdentifier, key: $0.key.rawValue), value: $0.value) }
      .dictionaryMap { $0 }
  }

  func asNote() throws -> Note? {
    guard let metadata = updates[.metadata]?.bookNoteMetadata else {
      return nil
    }
    var imageKeys: [String] = []
    var promptCollections: [String: PromptCollection] = [:]
    for key in updates.keys {
      if key.isWellKnown { continue }
      if key.isPrompt {
        promptCollections[key.rawValue] = try updates[key]?.promptCollectionInfo?.asPromptCollection()
      } else {
        imageKeys.append(key.rawValue)
      }
    }
    return Note(
      metadata: metadata,
      referencedImageKeys: imageKeys,
      text: updates[.noteText]?.text,
      promptCollections: promptCollections
    )
  }
}

private extension Dictionary where Key == ScopedKey, Value == [Version] {
  func asBookNoteMetadata() throws -> [String: BookNoteMetadata] {
    map { scopedKey, versions -> (key: String, value: KeyValueCRDT.Value?) in
      let tuple = (key: scopedKey.scope, value: versions.resolved(with: .lastWriterWins))
      return tuple
    }
    .dictionaryCompactMap { noteID, value -> (key: String, value: BookNoteMetadata)? in
      guard let value = value else { return nil } // Key was deleted, no need to log error.
      guard let json = value.json, let data = json.data(using: .utf8) else {
        Logger.keyValueNoteDatabase.error("Value for \(noteID) was not type JSON, ignoring")
        return nil
      }
      do {
        let bookNoteMetadata = try JSONDecoder.databaseDecoder.decode(BookNoteMetadata.self, from: data)
        return (noteID, bookNoteMetadata)
      } catch {
        Logger.keyValueNoteDatabase.error("Could not decode metadata: \(error)")
        return nil
      }
    }
  }
}

private extension PromptSchedulingMetadata {
  func recallEase(for studyLogEntry: StudyLog.Entry) -> RecallEase {
    if studyLogEntry.statistics.incorrect == 0, studyLogEntry.statistics.correct > 0 {
      return .good
    }
    switch mode {
    case .learning:
      return .again
    case .review:
      return .hard
    }
  }
}
