// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation

/// A struct that composes "Book" to include review & rating information.
///
/// ReviewedBook is "JSON compatible" with the underlying `Book` type. If you encoded a `ReviewedBook`, you can decode it as a Book (and lose the review/rating).
/// Similarly, if you have an encoded `Book`, you can decode it as a `ReviewedBook` with a nil review/rating.
///
/// `ReviewedBook` dynamically forwards `Book` key paths to the underlying Book, so you can just reference `reviewedBook.title` instead of `revieweBook.book.title`
@dynamicMemberLookup
public struct ReviewedBook: Codable, Hashable {
  public init(title: String, authors: [String], review: String? = nil, rating: Int? = nil) {
    self.book = Book(title: title, authors: authors)
    self.review = review
    self.rating = rating
  }

  public init(book: Book, review: String? = nil, rating: Int? = nil) {
    self.book = book
    self.review = review
    self.rating = rating
  }

  public init(_ book: Book) {
    self.book = book
  }

  /// The underlying review.
  public var book: Book

  /// A written review of this book.
  public var review: String?

  /// A rating for this book.
  public var rating: Int?

  private enum CodingKeys: CodingKey {
    case review
    case rating
  }

  public init(from decoder: Decoder) throws {
    self.book = try Book(from: decoder)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.review = try container.decodeIfPresent(String.self, forKey: .review)
    self.rating = try container.decodeIfPresent(Int.self, forKey: .rating)
  }

  public func encode(to encoder: Encoder) throws {
    try book.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(review, forKey: .review)
    try container.encode(rating, forKey: .rating)
  }

  subscript<T>(dynamicMember keyPath: WritableKeyPath<Book, T>) -> T {
    get { book[keyPath: keyPath] }
    set { book[keyPath: keyPath] = newValue }
  }
}
