// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// All properties needed to display a book in the book collection view.
struct BookViewProperties: Hashable {
  /// UUID for this page
  let pageKey: Note.Identifier

  let bookCategory: BookSection?

  init(pageKey: Note.Identifier) {
    self.pageKey = pageKey

    self.bookCategory = .read

//    if let book = noteProperties.book {
//      if let readingHistory = book.readingHistory {
//        if readingHistory.isCurrentlyReading {
//          self.bookCategory = .currentlyReading
//        } else {
//          self.bookCategory = .read
//        }
//      } else {
//        self.bookCategory = .wantToRead
//      }
//    } else {
//      self.bookCategory = nil
//    }
  }

  // "Identity" for hashing & equality is just the pageKey

  func hash(into hasher: inout Hasher) {
    hasher.combine(pageKey)
  }

  static func == (lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    lhs.pageKey == rhs.pageKey
  }
}