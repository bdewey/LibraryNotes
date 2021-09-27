// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import Logging

// TODO: Move this to BookKit
/// A book and its cover image.
public struct BookAndImage {
  public var book: AugmentedBook
  public var image: TypedData?

  public init(book: AugmentedBook, image: TypedData? = nil) {
    self.book = book
    self.image = image
  }
}

public extension BookAndImage {
  /// Create a `BookAndImage` where we download the cover image from OpenLibrary.
  init(book: AugmentedBook, isbn: String) async {
    self.book = book
    do {
      self.image = try await OpenLibrary.coverImage(forISBN: isbn)
    } catch {
      Logger.shared.error("Unexpected error getting OpenLibrary book cover for \(isbn): \(error)")
      self.image = nil
    }
  }
}

// TODO: This stays behind in Note+BookKit
extension Note {
  init(_ bookAndImage: BookAndImage, hashtags: String) {
    let book = bookAndImage.book
    var markdown = ""
    if let review = book.review {
      markdown += "\(review)\n\n"
    }
    if let rating = book.rating, rating > 0 {
      markdown += "#rating/" + String(repeating: "⭐️", count: rating) + " "
    }
    if !hashtags.trimmingCharacters(in: .whitespaces).isEmpty {
      markdown += "\(hashtags)\n\n"
    }
    if let tags = book.tags {
      for tag in tags {
        markdown += "\(tag)\n"
      }
    }
    self.init(markdown: markdown)
  }
}
