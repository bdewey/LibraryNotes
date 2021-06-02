// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

// swiftlint:disable identifier_name

import Combine
import Foundation
import Logging
import UniformTypeIdentifiers

struct LibraryThingBook: Codable {
  var title: String
  var authors: [LibraryThingAuthor]
  var date: Int?
  var review: String?
  var rating: Int?
  var isbn: [String: String]?
  var entrydate: DayComponents?
  var genre: [String]?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    // LibraryThing encodes "no authors" as "an array with an empty array", not "an empty array"
    self.authors = (try? container.decode([LibraryThingAuthor].self, forKey: .authors)) ?? []
    self.date = Int(try container.decode(String.self, forKey: .date))
    self.review = try? container.decode(String.self, forKey: .review)
    self.rating = try? container.decode(Int.self, forKey: .rating)
    self.isbn = try? container.decode([String: String].self, forKey: .isbn)
    self.entrydate = try? container.decode(DayComponents.self, forKey: .entrydate)
    self.genre = try? container.decode([String].self, forKey: .genre)
  }
}

struct LibraryThingAuthor: Codable {
  var lf: String?
  var fl: String?
}

extension Book {
  init(_ libraryThingBook: LibraryThingBook) {
    self.title = libraryThingBook.title
    self.authors = libraryThingBook.authors.compactMap { $0.fl }
    self.yearPublished = libraryThingBook.date
    self.isbn = libraryThingBook.isbn?["0"]
    self.isbn13 = libraryThingBook.isbn?["2"]
    self.review = libraryThingBook.review
    self.rating = libraryThingBook.rating
    self.tags = libraryThingBook.genre?.map { $0.asGenreTag() }.compactMap { $0 }
  }
}

extension String {
  func asGenreTag() -> String? {
    let coreGenre = lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
    if coreGenre.isEmpty {
      return nil
    } else {
      return "#genre/" + coreGenre
    }
  }
}
