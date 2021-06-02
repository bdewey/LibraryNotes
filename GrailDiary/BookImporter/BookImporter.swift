// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Foundation
import Logging

/// An object that can download cover images from OpenLibrary and bulk-create notes for books.
final class BookImporter {
  init(database: NoteDatabase, apiKey: String?) {
    self.database = database
    self.apiKey = apiKey
  }

  let database: NoteDatabase
  let apiKey: String?

  struct BookAndImage {
    var book: Book
    var creationDate: Date
    var image: TypedData?
  }

  private var booksAndImages = [BookAndImage]()
  private let imageCache = ImageCache()

  private var currentRequests = Set<AnyCancellable>()

  func importBooks(
    books: [(book: Book, creationDate: Date)],
    dryRun: Bool,
    downloadImages: Bool,
    progressCallback: @escaping (Int, Int) -> Void,
    completion: @escaping () -> Void
  ) {
    let semaphore = DispatchSemaphore(value: 5)
    let books = dryRun ? Array(books.prefix(10)) : books
    DispatchQueue.global(qos: .default).async {
      let group = DispatchGroup()
      for bookInfo in books {
        if downloadImages, let isbn = bookInfo.book.isbn13 {
          semaphore.wait()
          group.enter()
          let request = self.openLibraryCoverPublisher(for: bookInfo, isbn: isbn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bookAndImage in
              guard let self = self else { return }
              self.booksAndImages.append(bookAndImage)
              progressCallback(self.booksAndImages.count, books.count)
              semaphore.signal()
              group.leave()
            }
          self.currentRequests.insert(request)
        } else {
          DispatchQueue.main.async {
            self.booksAndImages.append(BookAndImage(book: bookInfo.book, creationDate: bookInfo.creationDate, image: nil))
            progressCallback(self.booksAndImages.count, books.count)
          }
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
          var note = Note(bookAndImage)
          note.creationTimestamp = bookAndImage.creationDate
          note.timestamp = bookAndImage.creationDate
          note.reference = .book(bookAndImage.book)
          try note.save(identifier: identifier, updateKey: updateIdentifier, to: db)
          if let typedData = bookAndImage.image {
            let binaryRecord = BinaryContentRecord(
              blob: typedData.data,
              noteId: identifier,
              key: Note.coverImageKey,
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

  private func openLibraryCoverPublisher(for bookInfo: (Book, Date), isbn: String) -> AnyPublisher<BookAndImage, Never> {
    return OpenLibrary.coverImagePublisher(isbn: isbn)
      .map { BookAndImage(book: bookInfo.0, creationDate: bookInfo.1, image: $0) }
      .catch { error -> Just<BookImporter.BookAndImage> in
        Logger.shared.error("Error getting image for book \(isbn): \(error)")
        return Just(BookAndImage(book: bookInfo.0, creationDate: bookInfo.1, image: nil))
      }
      .eraseToAnyPublisher()
  }
}

extension Note {
  init(_ bookAndImage: BookImporter.BookAndImage) {
    let book = bookAndImage.book
    var markdown = ""
    if let review = book.review {
      markdown += "\(review)\n\n"
    }
    if let rating = book.rating {
      markdown += "#rating/" + String(repeating: "⭐️", count: rating) + " "
    }
    markdown += "#libarything\n\n"
    if let tags = book.tags {
      for tag in tags {
        markdown += "\(tag)\n"
      }
    }
    self.init(markdown: markdown)
  }
}
