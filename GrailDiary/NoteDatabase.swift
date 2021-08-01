import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers

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
}

public protocol NoteDatabase {
  typealias IOCompletionHandler = (Bool) -> Void

  var fileURL: URL { get }
  var documentState: UIDocument.State { get }

  func open(completionHandler: IOCompletionHandler?)
  func close(completionHandler: IOCompletionHandler?)
  func refresh(completionHandler: IOCompletionHandler?)
  func flush() throws

  /// A publisher that sends a notification for any change anywhere in the database.
  var notesDidChange: AnyPublisher<Void, Never> { get }

  /// All ``BookNoteMetadata`` values in the database.
  var bookMetadata: [String: BookNoteMetadata] { get throws }

  /// A publisher that emits a new value whenever book metadata changes.
  func bookMetadataPublisher() -> AnyPublisher<[String: BookNoteMetadata], Error>

  // TODO: Figure out how to cache these.
  // TODO: Should ``bookMetadata`` become [String: (BookNoteMetadata, UIImage)]?
  /// Gets the cover image associated with a book.
  func coverImage(bookID: String, maxSize: CGFloat) -> UIImage?

  func createNote(_ note: Note) throws -> Note.Identifier
  func note(noteIdentifier: Note.Identifier) throws -> Note
  func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws
  func deleteNote(noteIdentifier: Note.Identifier) throws

  func writeAssociatedData(
    _ data: Data,
    noteIdentifier: Note.Identifier,
    role: String,
    type: UTType,
    key: String?
  ) throws -> String
  func readAssociatedData(from noteIdentifier: Note.Identifier, key: String) throws -> Data

  func bulkImportBooks(_ booksAndImages: [BookAndImage], hashtags: String) throws

  func renameHashtag(
    _ originalHashtag: String,
    to newHashtag: String,
    filter: (NoteMetadataRecord) -> Bool
  ) throws

  func search(for searchPattern: String) throws -> [Note.Identifier]

  func studySession(
    filter: ((Note.Identifier, NoteMetadataRecord) -> Bool)?,
    date: Date,
    completion: @escaping (StudySession) -> Void
  )
  func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedPrompts: Bool) throws
  func prompt(
    promptIdentifier: PromptIdentifier
  ) throws -> Prompt

  func promptCollectionPublisher(promptType: PromptType, tagged tag: String?) -> AnyPublisher<[ContentIdentifier], Swift.Error>

  // TODO: Create something general-purpose for the kvcrdt data implementation
  func attributedQuotes(for contentIdentifiers: [ContentIdentifier]) throws -> [AttributedQuote]
}

