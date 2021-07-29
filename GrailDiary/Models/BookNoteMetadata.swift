import BookKit
import Foundation

/// Holds the core information about books.
public struct BookNoteMetadata: Codable {
  // TODO: Why have this as well as book.title?
  /// Title of the note.
  public var title: String

  /// When this note was created in the database.
  public var creationTimestamp: Date

  /// Note tags.
  public var tags: [String] = []

  /// The book that this note is about.
  public var book: AugmentedBook?

  public init(title: String, creationTimestamp: Date, tags: [String] = [], book: AugmentedBook? = nil) {
    self.title = title
    self.creationTimestamp = creationTimestamp
    self.tags = tags
    self.book = book
  }
}

internal extension BookNoteMetadata {
  init(_ noteRecord: NoteRecord) {
    self.title = noteRecord.title
    self.creationTimestamp = noteRecord.creationTimestamp
  }
}
