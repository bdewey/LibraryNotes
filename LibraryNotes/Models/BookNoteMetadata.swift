// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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

  /// The "preferred title" of this note. If this note is about a specific book, the preferred title is derived from the book metadata. Otherwise, returns the `title`
  public var preferredTitle: String {
    if let book = book {
      var title = "_\(book.title)_"
      if !book.authors.isEmpty {
        let authors = book.authors.joined(separator: ", ")
        title += ": \(authors)"
      }
      if let publishedDate = book.originalYearPublished ?? book.yearPublished {
        title += " (\(publishedDate))"
      }
      return title
    } else {
      return title
    }
    // TODO: This isn't compiling on Xcode 13 and it should.
//    return (book?.markdownTitle) ?? title
  }

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
  public var book: AugmentedBook? {
    didSet {
      bookSection = book?.readingHistory?.inferredBookCategory ?? .wantToRead
      authorLastFirst = book?.authors.first?.nameLastFirst()
    }
  }

  /// In the book list, the section this book belongs in
  public var bookSection: BookSection?

  /// The book's first author, listed with last name first
  public var authorLastFirst: String?

  /// Information in this metadata structure that's worth putting in a full-text index for metadata surces.
  public var indexedContents: String? {
    guard let book = book else { return nil }
    return [book.title, book.authors.joined(separator: " ")].joined(separator: " ")
  }

  public static func == (lhs: BookNoteMetadata, rhs: BookNoteMetadata) -> Bool {
    lhs.title == rhs.title &&
      lhs.summary == rhs.summary &&
      lhs.creationTimestamp.withinInterval(1, of: rhs.creationTimestamp) &&
      lhs.modifiedTimestamp.withinInterval(1, of: rhs.modifiedTimestamp) &&
      lhs.tags == rhs.tags &&
      lhs.book == rhs.book
  }

  /// Fill out `bookSection` and `authorLastFirst`, which exist in "version 1" but didn't exist prior.
  mutating func upgradeToVersion1() {
    bookSection = book?.readingHistory?.inferredBookCategory ?? .wantToRead
    authorLastFirst = book?.authors.first?.nameLastFirst()
  }

  func upgradingToVersion1() -> Self {
    var copy = self
    copy.upgradeToVersion1()
    return copy
  }
}

public extension ReadingHistory {
  var inferredBookCategory: BookSection {
    if isCurrentlyReading {
      return .currentlyReading
    } else {
      return .read
    }
  }
}
