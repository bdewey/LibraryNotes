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

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    // LibraryThing encodes "no authors" as "an array with an empty array", not "an empty array"
    self.authors = (try? container.decode([LibraryThingAuthor].self, forKey: .authors)) ?? []
    self.date = Int(try container.decode(String.self, forKey: .date))
    self.review = try? container.decode(String.self, forKey: .review)
    self.rating = try? container.decode(Int.self, forKey: .rating)
    self.isbn = try? container.decode([String: String].self, forKey: .isbn)
  }
}

struct LibraryThingAuthor: Codable {
  var lf: String
  var fl: String
}

struct TypedData {
  var data: Data
  var type: UTType

  let uuid = UUID().uuidString
  var key: String {
    "./\(uuid).\(type.preferredFilenameExtension ?? "")"
  }
}

final class LibraryThingImporter {
  init(database: NoteDatabase, apiKey: String?, books: [LibraryThingBook]) {
    self.database = database
    self.apiKey = apiKey
    let limit = false
    self.books = limit ? Array(books.prefix(100)) : books
  }

  let database: NoteDatabase
  let apiKey: String?
  let books: [LibraryThingBook]
  let semaphore = DispatchSemaphore(value: 5)

  struct BookAndImage {
    var book: LibraryThingBook
    var image: TypedData?
  }

  private var booksAndImages = [BookAndImage]()
  private let imageCache = ImageCache()

  private var currentRequests = Set<AnyCancellable>()

  func importBooks(progressCallback: @escaping (Int, Int) -> Void, completion: @escaping () -> Void) {
    DispatchQueue.global(qos: .default).async {
      let group = DispatchGroup()
      for book in self.books {
        if let isbn = book.isbn?["2"] {
          self.semaphore.wait()
          group.enter()
          let request = self.openLibraryCoverPublisher(for: book, isbn: isbn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bookAndImage in
              guard let self = self else { return }
              self.booksAndImages.append(bookAndImage)
              progressCallback(self.booksAndImages.count, self.books.count)
              self.semaphore.signal()
              group.leave()
            }
          self.currentRequests.insert(request)
        } else {
          self.booksAndImages.append(BookAndImage(book: book, image: nil))
          progressCallback(self.booksAndImages.count, self.books.count)
        }
      }
      group.notify(queue: .main, execute: {
        self.saveBooksAndImages()
        Logger.shared.info("Finished processing books. Downloaded \(self.booksAndImages.filter { $0.image != nil }.count) images")
        completion()
      })
    }
  }

  private func saveBooksAndImages() {
    do {
      try database.bulkUpdate(updateBlock: { db, updateIdentifier in
        for bookAndImage in booksAndImages {
          let identifier = UUID().uuidString
          let note = Note(bookAndImage)
          try note.save(identifier: identifier, updateKey: updateIdentifier, to: db)
          if let typedData = bookAndImage.image {
            let binaryRecord = BinaryContentRecord(
              blob: typedData.data,
              noteId: identifier,
              key: typedData.key,
              role: "embeddedImage",
              mimeType: typedData.type.preferredMIMEType ?? "application/octet-stream"
            )
            try binaryRecord.save(db)
          }
        }
      })
    } catch {
      Logger.shared.error("Error importing books: \(error)")
    }
  }

  fileprivate enum LibraryThingError: Error {
    case invalidServerResponse
    case noThumbnailImage
    case unknown
    case cannotDecodeImage
  }

  private func openLibraryCoverPublisher(for book: LibraryThingBook, isbn: String) -> AnyPublisher<BookAndImage, Never> {
//    return Just(BookAndImage(book: book, image: nil)).eraseToAnyPublisher()
    return OpenLibrary.coverImagePublisher(isbn: isbn)
      .map { BookAndImage(book: book, image: $0) }
      .catch { error -> Just<LibraryThingImporter.BookAndImage> in
        Logger.shared.error("Error getting image for book \(isbn): \(error)")
        return Just(BookAndImage(book: book, image: nil))
      }
      .eraseToAnyPublisher()
  }
}

enum OpenLibrary {
  static func coverImagePublisher(isbn: String) -> AnyPublisher<TypedData, Error> {
    let url = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg")!
    return URLSession.shared.dataTaskPublisher(for: url)
      .tryMap { data, response in
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
          throw URLError(.badServerResponse)
        }
        if let mimeType = httpResponse.mimeType, let type = UTType(mimeType: mimeType) {
          return TypedData(data: data, type: type)
        }
        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.8) {
          return TypedData(data: jpegData, type: .jpeg)
        }
        throw URLError(.cannotDecodeRawData)
      }
      .eraseToAnyPublisher()
  }
}

extension Note {
  init(_ bookAndImage: LibraryThingImporter.BookAndImage) {
    let book = bookAndImage.book
    var markdown = "# _\(book.title)_"
    if !book.authors.isEmpty {
      markdown += ": " + book.authors.map { $0.fl }.joined(separator: ", ")
    }
    if let date = book.date {
      markdown += " (\(date))"
    }
    if let typedData = bookAndImage.image {
      markdown += "\n\n![cover](\(typedData.key))"
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
