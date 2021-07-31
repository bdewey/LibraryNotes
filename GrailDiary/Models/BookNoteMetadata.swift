import BookKit
import Foundation

/// Holds the core information about books.
public struct BookNoteMetadata: Codable, Equatable {
  public init(title: String, summary: String? = nil, creationTimestamp: Date, modifiedTimestamp: Date, tags: [String] = [], folder: String? = nil, book: AugmentedBook? = nil) {
    self.title = title
    self.summary = summary
    self.creationTimestamp = creationTimestamp
    self.modifiedTimestamp = modifiedTimestamp
    self.tags = tags
    self.folder = folder
    self.book = book
  }

  // TODO: Why have this as well as book.title?
  /// Title of the note.
  public var title: String

  /// A short summary of the book -- displayed in the list view
  public var summary: String?

  /// When this note was created in the database.
  public var creationTimestamp: Date

  /// When this note was last modified
  public var modifiedTimestamp: Date

  /// Note tags.
  public var tags: [String] = []

  /// Optional folder for this note. Currently used only to implement the trash can.
  public var folder: String?

  /// The book that this note is about.
  public var book: AugmentedBook?
}

public extension Sequence where Element == BookNoteMetadata {
  var hashtags: [String] {
    let hashtags = self
      .filter { $0.folder != PredefinedFolder.recentlyDeleted.rawValue }
      .reduce(into: Set<String>()) { hashtags, metadata in
        hashtags.formUnion(metadata.tags)
      }
    return Array(hashtags).sorted()
  }
}

internal extension BookNoteMetadata {
  init(_ noteMetadataRecord: NoteMetadataRecord) {
    self.title = noteMetadataRecord.title
    self.summary = noteMetadataRecord.summary
    self.creationTimestamp = noteMetadataRecord.creationTimestamp
    self.modifiedTimestamp = noteMetadataRecord.modifiedTimestamp
    self.tags = noteMetadataRecord.noteLinks.map { $0.targetTitle }
    self.folder = noteMetadataRecord.folder
    self.book = noteMetadataRecord.book
  }
}
