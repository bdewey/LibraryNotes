import Combine
import Foundation
import KeyValueCRDT
import Logging
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
    Logger.keyValueNoteDatabase.debug("\(#function) not implemented")
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

  func coverImage(bookID: String) -> UIImage? {
    let data = try? keyValueDocument.keyValueCRDT.read(key: NoteDatabaseKey.coverImage, scope: bookID).resolved(with: .lastWriterWins)?.blob
    if let data = data, let image = UIImage(data: data) {
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
  }

  func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedPrompts: Bool) throws {
    throw KeyValueNoteDatabaseError.notImplemented
  }

  func prompt(promptIdentifier: PromptIdentifier) throws -> Prompt {
    throw KeyValueNoteDatabaseError.notImplemented
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
