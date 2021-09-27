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

  @MainActor
  func importBooks(
    request: BookImportRequest<[AugmentedBook]>,
    progressCallback: @escaping @MainActor(Int, Int) -> Void
  ) async {
    let books = request.dryRun ? Array(request.item.shuffled().prefix(10)) : request.item
    if request.downloadCoverImages {
      await withTaskGroup(of: BookAndImage.self) { group in
        for book in books {
          group.addTask {
            if let isbn = book.isbn13 {
              return await BookAndImage(book: book, isbn: isbn)
            } else {
              return BookAndImage(book: book, image: nil)
            }
          }
        }
        for await bookAndImage in group {
          booksAndImages.append(bookAndImage)
          progressCallback(booksAndImages.count, books.count)
        }
      }
    } else {
      booksAndImages = books.map { BookAndImage(book: $0, image: nil) }
    }
    saveBooksAndImages(hashtags: request.hashtags)
    Logger.shared.info("Finished processing books. Downloaded \(booksAndImages.filter { $0.image != nil }.count) images")
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
}
