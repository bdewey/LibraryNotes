// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Core model for a "book"
public struct Book: Hashable, Codable {
  /// The book title
  public var title: String

  /// The book authors, in "First Last" format
  public var authors: [String]

  /// When this specific volume was published.
  public var yearPublished: Int?

  /// In the case of a work with multiple editions, this is the year the book was originally published.
  public var originalYearPublished: Int?

  /// The book publisher.
  public var publisher: String?

  /// 10-digit ISBN
  public var isbn: String?

  /// 13-digit ISBN
  public var isbn13: String?

  /// Dates when this book was read
  public var dateRead: [Date]?

  /// Number of pages in the book
  public var numberOfPages: Int?

  // TODO: Figure out if I actually want these in the "Book" model
  var review: String?
  var rating: Int?

  // TODO: This should probably be in an extension somewhere.
  /// A citation for this book in simple Markdown.
  var markdownTitle: String {
    var title = "_\(self.title)_"
    if !authors.isEmpty {
      let authors = self.authors.joined(separator: ", ")
      title += ": \(authors)"
    }
    if let publishedDate = yearPublished {
      title += " (\(publishedDate))"
    }
    return title
  }
}
