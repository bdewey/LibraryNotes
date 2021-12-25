// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UIKit

/// An item in the book collection view.
enum BookCollectionViewItem: Hashable, CustomStringConvertible {
  /// The header for a section of books.
  case header(BookSection, Int)

  /// Header for a section of books read in a particular year
  case yearReadHeader(Int, Int)

  /// A single book
  case book(Note.Identifier)

  var description: String {
    switch self {
    case .book(let noteIdentifier):
      return "Page \(noteIdentifier)"
    case .header(let category, let count):
      return "\(category) (\(count))"
    case .yearReadHeader(let yearRead, let count):
      return "Read \(yearRead) (\(count))"
    }
  }

  var isHeader: Bool {
    switch self {
    case .header, .yearReadHeader:
      return true
    case .book:
      return false
    }
  }

  /// If this item represents a header, contains the primary & secondary text for the header row
  var headerText: (primaryHeaderText: String, secondaryHeaderText: String)? {
    switch self {
    case .header(let bookSection, let count):
      return (primaryHeaderText: bookSection.headerText, secondaryHeaderText: "\(count)")
    case .yearReadHeader(let yearRead, let count):
      return (primaryHeaderText: "Read in \(yearRead)", secondaryHeaderText: "\(count)")
    case .book:
      return nil
    }
  }

  /// The note identifier for the item, if it exists.
  var noteIdentifier: Note.Identifier? {
    if case .book(let noteIdentifier) = self {
      return noteIdentifier
    } else {
      return nil
    }
  }
}

internal extension NSDiffableDataSourceSectionSnapshot where ItemIdentifierType == BookCollectionViewItem {
  var bookCount: Int {
    var bookCount = 0
    for item in rootItems {
      switch item {
      case .header(_, let count):
        bookCount += count
      case .yearReadHeader(_, let count):
        bookCount += count
      case .book:
        bookCount += 1
      }
    }
    return bookCount
  }

  mutating func collapseSections(in collapsedSections: Set<BookSection>) {
    for item in rootItems {
      guard case .header(let category, _) = item else { continue }
      if collapsedSections.contains(category) {
        collapse([item])
      }
    }
  }
}
