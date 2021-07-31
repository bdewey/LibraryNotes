//
//  BookAndImage.swift
//  BookAndImage
//
//  Created by Brian Dewey on 7/31/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import BookKit
import Foundation

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
