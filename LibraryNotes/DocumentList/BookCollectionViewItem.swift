// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import LibraryNotesCore
import UIKit

/// A section in the book collection view.
enum BookCollectionViewSection: Hashable, Sendable {
  case category(BookSection)
  case readYear(Int)

  var headerText: String {
    switch self {
    case .category(let category):
      category.headerText
    case .readYear(let year):
      "Read in \(year)"
    }
  }

  var includesBooksInBookCount: Bool {
    switch self {
    case .category(.other):
      false
    case .category, .readYear:
      true
    }
  }

  func isExpandedByDefault(currentYear: Int) -> Bool {
    switch self {
    case .category(.currentlyReading):
      true
    case .readYear(let year):
      year == currentYear
    case .category:
      false
    }
  }
}

/// An item in the book collection view.
enum BookCollectionViewItem: Hashable, CustomStringConvertible, Sendable {
  /// The header for a section of books.
  case header(BookCollectionViewSection, Int)

  /// A single book
  case book(Note.Identifier, BookCollectionViewSection)

  var description: String {
    switch self {
    case .book(let noteIdentifier, _):
      "Page \(noteIdentifier)"
    case .header(let section, let count):
      "\(section.headerText) (\(count))"
    }
  }

  var isHeader: Bool {
    switch self {
    case .header:
      true
    case .book:
      false
    }
  }

  /// If this item represents a header, contains the primary & secondary text for the header row
  var headerText: (primaryHeaderText: String, secondaryHeaderText: String)? {
    switch self {
    case .header(let section, let count):
      (primaryHeaderText: section.headerText, secondaryHeaderText: "\(count)")
    case .book:
      nil
    }
  }

  /// The note identifier for the item, if it exists.
  var noteIdentifier: Note.Identifier? {
    if case .book(let noteIdentifier, _) = self {
      return noteIdentifier
    } else {
      return nil
    }
  }

  /// Returns true if the receiver is a book that contains `noteIdentifier`
  /// - Parameter noteIdentifier: The note identifier to test for.
  /// - Returns: True if this is a book that matches the note identifier.
  func matchesNoteIdentifier(_ noteIdentifier: Note.Identifier) -> Bool {
    switch self {
    case .header:
      false
    case .book(let myNoteIdentifier, _):
      myNoteIdentifier == noteIdentifier
    }
  }
}

extension NSDiffableDataSourceSectionSnapshot where ItemIdentifierType == BookCollectionViewItem {
  var bookCount: Int {
    var bookCount = 0
    for item in rootItems {
      switch item {
      case .header(let section, let count) where section.includesBooksInBookCount:
        bookCount += count
      case .book:
        bookCount += 1
      case .header:
        break
      }
    }
    return bookCount
  }
}
