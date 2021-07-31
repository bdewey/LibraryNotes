// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
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

  private var booksAndImages = [BookAndImage]()
  private let imageCache = ImageCache()

  private var currentRequests = Set<AnyCancellable>()

  func importBooks(
    books: [AugmentedBook],
    hashtags: String,
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
            self.booksAndImages.append(BookAndImage(book: bookInfo, image: nil))
            progressCallback(self.booksAndImages.count, books.count)
          }
        }
      }
      group.notify(queue: .main, execute: {
        self.saveBooksAndImages(hashtags: hashtags)
        Logger.shared.info("Finished processing books. Downloaded \(self.booksAndImages.filter { $0.image != nil }.count) images")
        completion()
      })
    }
  }

  private func saveBooksAndImages(hashtags: String) {
    do {
      try database.bulkImportBooks(booksAndImages, hashtags: hashtags)
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

  private func openLibraryCoverPublisher(for bookInfo: AugmentedBook, isbn: String) -> AnyPublisher<BookAndImage, Never> {
    return OpenLibrary.coverImagePublisher(isbn: isbn)
      .map { BookAndImage(book: bookInfo, image: $0) }
      .catch { error -> Just<BookAndImage> in
        Logger.shared.error("Error getting image for book \(isbn): \(error)")
        return Just(BookAndImage(book: bookInfo, image: nil))
      }
      .eraseToAnyPublisher()
  }
}
