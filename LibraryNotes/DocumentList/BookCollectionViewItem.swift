// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UIKit

/// An item in the book collection view.
enum BookCollectionViewItem: Hashable, CustomStringConvertible {
  /// The header for a section of books.
  case header(BookSection, Int)

  /// A single book
  case book(Note.Identifier)

  var description: String {
    switch self {
    case .book(let noteIdentifier):
      return "Page \(noteIdentifier)"
    case .header(let category, let count):
      return "\(category) (\(count))"
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
