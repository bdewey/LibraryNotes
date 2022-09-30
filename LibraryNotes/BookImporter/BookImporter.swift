// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Foundation
import KeyValueCRDT
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
      progressCallback(booksAndImages.count, books.count)
    }
    // don't tie up the main thread when saving
    // TODO: This doesn't match my mental model of Task.
    // I thought this would go to the background and not tie up the main thread. However, without
    // the explicit `Task.yield()`, the main thread blocks.
    let task = Task { () -> [NoteUpdatePayload] in
      var results: [NoteUpdatePayload] = []
      for bookAndImage in booksAndImages {
        await Task.yield()
        results.append(try bookAndImage.asNoteUpdatePayload(hashtags: request.hashtags))
      }
      return results
    }
    do {
      let payload = try await task.value
      try database.bulkWrite(payload)
      Logger.shared.info("Finished processing books. Downloaded \(booksAndImages.filter { $0.image != nil }.count) images")
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

private extension BookAndImage {
  func asNoteUpdatePayload(hashtags: String) throws -> NoteUpdatePayload {
    var payload = NoteUpdatePayload(noteIdentifier: UUID().uuidString)
    let bookAddedDate = book.dateAdded ?? Date()
    var metadata = BookNoteMetadata(
      title: book.title,
      creationTimestamp: bookAddedDate,
      modifiedTimestamp: bookAddedDate
    )
    metadata.book = book
    if let dateAdded = book.dateAdded {
      // Assume we read the book
      let components = Calendar.current.dateComponents([.year, .month, .day], from: dateAdded)
      var readingHistory = ReadingHistory()
      readingHistory.finishReading(finishDate: components)
      metadata.book?.readingHistory = readingHistory
    }
    metadata.tags = hashtags.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    payload.insert(key: .metadata, value: try Value(metadata))
    payload.insert(key: .bookIndex, value: Value(metadata.indexedContents))
    if let review = book.review {
      payload.insert(key: .noteText, value: .text(review))
    }
    if let imageData = image {
      payload.insert(key: .coverImage, value: .blob(mimeType: imageData.type.preferredMIMEType ?? "application/octet-stream", blob: imageData.data))
    }
    return payload
  }
}
