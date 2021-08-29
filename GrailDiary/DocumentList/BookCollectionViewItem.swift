//
//  BookCollectionViewItem.swift
//  BookCollectionViewItem
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

/// An item in the book collection view.
enum BookCollectionViewItem: Hashable, CustomStringConvertible {
  /// The header for a section of books.
  case header(BookSection, Int)

  /// A single book
  case book(BookViewProperties)

  var description: String {
    switch self {
    case .book(let viewProperties):
      return "Page \(viewProperties.pageKey)"
    case .header(let category, let count):
      return "\(category) (\(count))"
    }
  }

  /// The note identifier for the item, if it exists.
  var noteIdentifier: Note.Identifier? {
    if case .book(let viewProperties) = self {
      return viewProperties.pageKey
    } else {
      return nil
    }
  }

  /// If the receiver is a page, returns the category for that page, else nil.
  var bookCategory: BookSection? {
    if case .book(let properties) = self {
      return properties.bookCategory
    } else {
      return nil
    }
  }
}
