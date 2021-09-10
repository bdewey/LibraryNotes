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
    progressCallback: @escaping @MainActor (Int, Int) -> Void
  ) async {
    let books = request.dryRun ? Array(request.item.shuffled().prefix(10)) : request.item
    for bookInfo in books {
      if request.downloadCoverImages, let isbn = bookInfo.book.isbn13 {
        booksAndImages.append(await BookAndImage(book: bookInfo, isbn: isbn))
      } else {
        booksAndImages.append(BookAndImage(book: bookInfo, image: nil))
      }
      progressCallback(booksAndImages.count, books.count)
    }
    self.saveBooksAndImages(hashtags: request.hashtags)
    Logger.shared.info("Finished processing books. Downloaded \(self.booksAndImages.filter { $0.image != nil }.count) images")
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
