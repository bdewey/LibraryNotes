// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

// swiftlint:disable identifier_name

import Foundation

struct LibraryThingBook: Codable {
  var title: String
  var authors: [LibraryThingAuthor]
  var date: Int?
  var review: String?
  var rating: Int?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    // LibraryThing encodes "no authors" as "an array with an empty array", not "an empty array"
    self.authors = (try? container.decode([LibraryThingAuthor].self, forKey: .authors)) ?? []
    self.date = Int(try container.decode(String.self, forKey: .date))
    self.review = try? container.decode(String.self, forKey: .review)
    self.rating = try? container.decode(Int.self, forKey: .rating)
  }
}

struct LibraryThingAuthor: Codable {
  var lf: String
  var fl: String
}

extension Note {
  init(_ book: LibraryThingBook) {
    var markdown = "# _\(book.title)_"
    if !book.authors.isEmpty {
      markdown += ": " + book.authors.map { $0.fl }.joined(separator: ", ")
    }
    if let date = book.date {
      markdown += " (\(date))"
    }
    markdown += "\n\n"
    if let review = book.review {
      markdown += "tl;dr: \(review)\n\n"
    }
    if let rating = book.rating {
      markdown += "#rating/" + String(repeating: "⭐️", count: rating) + " "
    }
    markdown += "#libarything\n\n"
    self.init(markdown: markdown)
  }
}
