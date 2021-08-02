import Combine
import Foundation
import KeyValueCRDT
import Logging
import SpacedRepetitionScheduler
import UIKit
import UniformTypeIdentifiers

private extension Logger {
  static let keyValueNoteDatabase: Logger = {
    var logger = Logger(label: "org.brians-brain.KeyValueNoteDatabase")
    logger.logLevel = .debug
    return logger
  }()
}

private extension JSONEncoder {
  static let databaseEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
}

private extension JSONDecoder {
  static let databaseDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}

enum NoteDatabaseKey {
  static let metadata = ".metadata"
  static let coverImage = "coverImage"
  static let noteText = "noteText"
}

struct PromptCollectionIdentifier: RawRepresentable {
  init(promptType: PromptType, count: Int, id: String) {
    self.promptType = promptType
    self.count = count
    self.id = id
  }

  let promptType: PromptType
  let count: Int
  let id: String

  var rawValue: String {
    "prompt=\(promptType.rawValue);count=\(count);id=\(id)"
  }

  init?(rawValue: String) {
    let segments = rawValue.split(separator: ";")
    guard segments[0].hasPrefix("prompt=") else { return nil }
    self.promptType = PromptType(rawValue: String(segments[0].dropFirst(7)))
    guard segments[1].hasPrefix("count="), let count = Int(String(segments[1].dropFirst(6))) else { return nil }
    self.count = count
    guard segments[2].hasPrefix("id=") else { return nil }
    self.id = String(segments[3].dropFirst(3))
  }
}

enum KeyValueNoteDatabaseError: Error {
  case notImplemented
}

/// An implementation of ``NoteDatabase`` based upon ``UIKeyValueDocument``
final class KeyValueNoteDatabase: NoteDatabase {
  init(fileURL: URL, author: Author) throws {
    self.keyValueDocument = try UIKeyValueDocument(fileURL: fileURL, author: author)
  }

  private let keyValueDocument: UIKeyValueDocument

  var fileURL: URL { keyValueDocument.fileURL }

  var documentState: UIDocument.State { keyValueDocument.documentState }

  func open(completionHandler: IOCompletionHandler?) {
    keyValueDocument.open(completionHandler: completionHandler)
  }

  func close(completionHandler: IOCompletionHandler?) {
    keyValueDocument.close(completionHandler: completionHandler)
  }

  func refresh(completionHandler: IOCompletionHandler?) {
    Logger.keyValueNoteDatabase.debug("\(#function) not implemented")
  }

  func flush() throws {
    keyValueDocument.save(to: fileURL, for: .forOverwriting, completionHandler: nil)
  }

  var notesDidChange: AnyPublisher<Void, Never> {
    keyValueDocument.keyValueCRDT
      .didChangePublisher()
      .map { _ in () } // turn any value to a Void
      .catch { _ in Just<Void>(Void()) }
      .eraseToAnyPublisher()
  }

  var bookMetadata: [String: BookNoteMetadata] {
    do {
      let results = try keyValueDocument.keyValueCRDT.bulkRead(key: NoteDatabaseKey.metadata)
      return try results.asBookNoteMetadata()
    } catch {
      Logger.keyValueNoteDatabase.critical("Could not read book metadata: \(error)")
      fatalError()
    }
  }

  func bookMetadataPublisher() -> AnyPublisher<[String: BookNoteMetadata], Error> {
    keyValueDocument.keyValueCRDT
      .readPublisher(key: NoteDatabaseKey.metadata)
      .tryMap({ try $0.asBookNoteMetadata() })
      .eraseToAnyPublisher()
  }

  func coverImage(bookID: String, maxSize: CGFloat) -> UIImage? {
    let data = try? keyValueDocument.keyValueCRDT.read(key: NoteDatabaseKey.coverImage, scope: bookID).resolved(with: .lastWriterWins)?.blob
    if let data = data, let image = data.image(maxSize: maxSize) {
      return image
    } else {
      return nil
    }
  }

  func createNote(_ note: Note) throws -> Note.Identifier {
    let noteID = UUID().uuidString
    try saveBookNote(note, identifier: noteID)
    return noteID
  }

  func note(noteIdentifier: Note.Identifier) throws -> Note {
    guard let json = try keyValueDocument.keyValueCRDT.read(key: NoteDatabaseKey.metadata, scope: noteIdentifier).resolved(with: .lastWriterWins)?.json else {
      throw NoteDatabaseError.noSuchNote
    }
    let metadata = try JSONDecoder.databaseDecoder.decode(BookNoteMetadata.self, from: json.data(using: .utf8)!)
    let text = try keyValueDocument.keyValueCRDT.read(key: NoteDatabaseKey.noteText, scope: noteIdentifier).resolved(with: .lastWriterWins)?.text
    return Note(
      metadata: metadata,
      referencedImageKeys: [],
      text: text,
      promptCollections: [:]
    )
  }

  func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws {
    let initialNote = try note(noteIdentifier: noteIdentifier)
    let updatedNote = updateBlock(initialNote)
    try saveBookNote(updatedNote, identifier: noteIdentifier)
  }

  func deleteNote(noteIdentifier: Note.Identifier) throws {
    let updates = try keyValueDocument.keyValueCRDT.keys(scope: noteIdentifier).dictionaryMap {
      (key: $0, value: Value.null)
    }
    try keyValueDocument.keyValueCRDT.bulkWrite(updates)
  }

  func writeAssociatedData(_ data: Data, noteIdentifier: Note.Identifier, role: String, type: UTType, key: String?) throws -> String {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func readAssociatedData(from noteIdentifier: Note.Identifier, key: String) throws -> Data {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func bulkImportBooks(_ booksAndImages: [BookAndImage], hashtags: String) throws {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func renameHashtag(_ originalHashtag: String, to newHashtag: String, filter: (NoteMetadataRecord) -> Bool) throws {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func search(for searchPattern: String) throws -> [Note.Identifier] {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func studySession(filter: ((Note.Identifier, NoteMetadataRecord) -> Bool)?, date: Date, completion: @escaping (StudySession) -> Void) {
    DispatchQueue.global(qos: .userInteractive).async {
      let studySession = self.studySession(filter: filter, date: date)
      DispatchQueue.main.async {
        completion(studySession)
      }
    }
  }

  private func studySession(filter: ((Note.Identifier, NoteMetadataRecord) -> Bool)?, date: Date) -> StudySession {
    let results: [ScopedKey: [Version]]
    do {
      results = try keyValueDocument.keyValueCRDT.bulkRead(isIncluded: { _, key in
        key.hasPrefix("prompt=") || key == NoteDatabaseKey.metadata
      })
    } catch {
      Logger.keyValueNoteDatabase.error("Could not read prompt keys: \(error)")
      return StudySession()
    }
    var studySession = StudySession()
    for (scopedKey, versions) in results where scopedKey.key.starts(with: "prompt=") {
      guard let json = versions.resolved(with: .lastWriterWins)?.json, let data = json.data(using: .utf8) else {
        continue
      }
      do {
        let promptInfo = try JSONDecoder.databaseDecoder.decode(PromptCollectionInfo.self, from: data)
        var promptIdentifiers = [PromptIdentifier]()
        for (index, prompt) in promptInfo.promptStatistics.enumerated() where (prompt.due ?? .distantPast) <= date {
          promptIdentifiers.append(PromptIdentifier(noteId: scopedKey.scope, promptKey: scopedKey.key, promptIndex: index))
        }
        if !promptIdentifiers.isEmpty {
          let metadata = results[ScopedKey(scope: scopedKey.scope, key: NoteDatabaseKey.metadata)]?.metadata
          let innerStudySession = StudySession(
            promptIdentifiers,
            properties: CardDocumentProperties(
              documentName: scopedKey.scope,
              attributionMarkdown: metadata?.title ?? ""
            )
          )
          studySession += innerStudySession
        }
      } catch {
        Logger.keyValueNoteDatabase.error("Could not decode prompt info: \(error)")
      }
    }
    return studySession
  }

  func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedPrompts: Bool) throws {
    let scopedKeysToFetch = studySession.results.keys.map { ScopedKey(scope: $0.noteId, key: $0.promptKey) }
    let promptInfo = try keyValueDocument.keyValueCRDT
      .bulkRead(keys: scopedKeysToFetch.map({ $0.key }))
      .dictionaryCompactMap(mapping: { scopedKey, versions -> (key: ScopedKey, value: PromptCollectionInfo)? in
        guard let info = versions.promptCollectionInfo else { return nil }
        return (key: scopedKey, value: info)
      })
    Logger.keyValueNoteDatabase.debug("Fetched \(promptInfo.count) collections for update")

    var updates: [ScopedKey: Value] = [:]
    for (promptIdentifier, answerStatistics) in studySession.results {
      // 1. Generate a StudyLogEntry. Currently this is write-only; I never read these back. In theory one could reconstruct
      // the prompt scheduling information from them.
      let entry = StudyLogEntry(
        timestamp: date,
        correct: answerStatistics.correct,
        incorrect: answerStatistics.incorrect,
        promptIndex: promptIdentifier.promptIndex
      )
      let formattedTime = ISO8601DateFormatter().string(from: date)
      // Each key is globally unique so there should never be collisions.
      let key = "\(formattedTime).\(UUID().uuidString)"
      let jsonData = try JSONEncoder.databaseEncoder.encode(entry)
      // The scope is what ties this entry to its corresponding scope & key.
      let entryKey = ScopedKey(scope: "note=\(promptIdentifier.noteId);\(promptIdentifier.promptKey)", key: key)
      updates[entryKey] = .json(String(data: jsonData, encoding: .utf8)!)

      // 2. Update the corresponding prompt info.
      let scopedKey = ScopedKey(scope: promptIdentifier.noteId, key: promptIdentifier.promptKey)
      if var info = promptInfo[scopedKey], promptIdentifier.promptIndex < info.promptStatistics.endIndex {
        var schedulingItem = info.promptStatistics[promptIdentifier.promptIndex].schedulingItem

        let delay: TimeInterval
        if let lastReview = info.promptStatistics[promptIdentifier.promptIndex].lastReview, let idealInterval = info.promptStatistics[promptIdentifier.promptIndex].idealInterval {
          let idealDate = lastReview.addingTimeInterval(idealInterval)
          delay = max(entry.timestamp.timeIntervalSince(idealDate), 0)
        } else {
          delay = 0
        }

        try schedulingItem.update(with: .standard, recallEase: entry.recallEase, timeIntervalSincePriorReview: delay)
        info.promptStatistics[promptIdentifier.promptIndex].applySchedulingItem(schedulingItem, on: date)
        updates[scopedKey] = try Value(info)
      } else {
        Logger.keyValueNoteDatabase.error("Could not find info or index for \(scopedKey)")
        assertionFailure()
      }
    }
    try keyValueDocument.keyValueCRDT.bulkWrite(updates)
  }

  func prompt(promptIdentifier: PromptIdentifier) throws -> Prompt {
    guard let json = try keyValueDocument.keyValueCRDT.read(key: promptIdentifier.promptKey, scope: promptIdentifier.noteId).resolved(with: .lastWriterWins)?.json else {
      throw NoteDatabaseError.unknownPromptCollection
    }
    let promptInfo = try JSONDecoder.databaseDecoder.decode(PromptCollectionInfo.self, from: json.data(using: .utf8)!)
    guard let klass = PromptType.classMap[promptInfo.type], let collection = klass.init(rawValue: promptInfo.rawValue) else {
      throw NoteDatabaseError.unknownPromptType
    }
    return collection.prompts[promptIdentifier.promptIndex]
  }

  func promptCollectionPublisher(promptType: PromptType, tagged tag: String?) -> AnyPublisher<[ContentIdentifier], Error> {
    return Fail<[ContentIdentifier], Error>(error: KeyValueNoteDatabaseError.notImplemented).eraseToAnyPublisher()
  }

  func attributedQuotes(for contentIdentifiers: [ContentIdentifier]) throws -> [AttributedQuote] {
    throw KeyValueNoteDatabaseError.notImplemented
  }
}

private extension KeyValueNoteDatabase {
  func saveBookNote(_ note: Note, identifier: Note.Identifier) throws {
    let encodedMetadata = try JSONEncoder.databaseEncoder.encode(note.metadata)
    try keyValueDocument.keyValueCRDT.writeJson(String(data: encodedMetadata, encoding: .utf8)!, to: NoteDatabaseKey.metadata, scope: identifier)
    if let text = note.text {
      try keyValueDocument.keyValueCRDT.writeText(text, to: NoteDatabaseKey.noteText, scope: identifier)
    } else {
      try keyValueDocument.keyValueCRDT.delete(key: NoteDatabaseKey.noteText, scope: identifier)
    }
  }
}

private extension Dictionary where Key == ScopedKey, Value == [Version] {
  func asBookNoteMetadata() throws -> [String: BookNoteMetadata] {
    self.map { scopedKey, versions -> (key: String, value: KeyValueCRDT.Value?) in
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

private extension StudyLogEntry {
  var recallEase: RecallEase {
    if correct > 0, incorrect == 0 {
      return .good
    }
    if correct > 0, incorrect == 1 {
      return .hard
    }
    return .again
  }
}

private extension Value {
  init(_ promptCollectionInfo: PromptCollectionInfo) throws {
    let jsonData = try JSONEncoder.databaseEncoder.encode(promptCollectionInfo)
    self = .json(String(data: jsonData, encoding: .utf8)!)
  }
}

private extension Array where Element == Version {
  var metadata: BookNoteMetadata? {
    guard let json = self.resolved(with: .lastWriterWins)?.json else { return nil }
    return try? JSONDecoder.databaseDecoder.decode(BookNoteMetadata.self, from: json.data(using: .utf8)!)
  }

  var promptCollectionInfo: PromptCollectionInfo? {
    guard let json = self.resolved(with: .lastWriterWins)?.json else { return nil }
    return try? JSONDecoder.databaseDecoder.decode(PromptCollectionInfo.self, from: json.data(using: .utf8)!)
  }
}
