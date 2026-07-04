// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
@testable import Library_Notes
import XCTest

final class MarkdownExportTests: XCTestCase {
  func testBookFrontmatterQuotesStringScalars() {
    let book = AugmentedBook(
      book: Book(
        title: "In Defense of Food: An Eater's Manifesto",
        authors: [
          "Pollan: Michael",
          #"Author "With Quotes""#,
        ],
        yearPublished: 2008
      ),
      rating: 5
    )

    XCTAssertEqual(
      MarkdownExport.frontmatter(for: book),
      """
      ---
      title: "In Defense of Food: An Eater's Manifesto"
      authors:
      - "Pollan: Michael"
      - "Author \\"With Quotes\\""
      year-published: 2008
      rating: 5
      ---


      """
    )
  }
}

final class BookCoverSearchQueryTests: XCTestCase {
  func testGoogleBooksCoverSearchQueryUsesTitleOnly() {
    let book = AugmentedBook(title: "Dune", authors: [])

    XCTAssertEqual(book.googleBooksCoverSearchQuery, "Dune")
  }

  func testGoogleBooksCoverSearchQueryUsesAuthorsOnlyWhenTitleIsEmpty() {
    let book = AugmentedBook(title: "  ", authors: ["Frank Herbert"])

    XCTAssertEqual(book.googleBooksCoverSearchQuery, "Frank Herbert")
  }

  func testGoogleBooksCoverSearchQueryUsesTitleAndAuthors() {
    let book = AugmentedBook(title: "Dune", authors: ["Frank Herbert", "Brian Herbert"])

    XCTAssertEqual(book.googleBooksCoverSearchQuery, "Dune Frank Herbert Brian Herbert")
  }
}

final class BookEditMetadataMergeTests: XCTestCase {
  func testPreservingPersonalMetadataKeepsReadingHistoryFromExistingBook() {
    var readingHistory = ReadingHistory()
    readingHistory.finishReading(finishDate: DateComponents(year: 2026, month: 7, day: 3))

    var existingBook = AugmentedBook(
      book: Book(
        title: "Old Title",
        authors: ["Original Author"],
        yearPublished: 1999
      ),
      review: "A personal review",
      rating: 4,
      dateAdded: Date(timeIntervalSince1970: 12345)
    )
    existingBook.readingHistory = readingHistory

    let editedBook = AugmentedBook(
      book: Book(
        title: "New Title",
        authors: ["Updated Author"],
        yearPublished: 2024,
        publisher: "Updated Publisher",
        isbn13: "9781234567890",
        numberOfPages: 321,
        tags: ["Science Fiction"]
      )
    )

    let mergedBook = editedBook.preservingPersonalMetadata(from: existingBook)

    XCTAssertEqual(mergedBook.title, "New Title")
    XCTAssertEqual(mergedBook.authors, ["Updated Author"])
    XCTAssertEqual(mergedBook.yearPublished, 2024)
    XCTAssertEqual(mergedBook.publisher, "Updated Publisher")
    XCTAssertEqual(mergedBook.isbn13, "9781234567890")
    XCTAssertEqual(mergedBook.numberOfPages, 321)
    XCTAssertEqual(mergedBook.tags, ["Science Fiction"])
    XCTAssertEqual(mergedBook.review, existingBook.review)
    XCTAssertEqual(mergedBook.rating, existingBook.rating)
    XCTAssertEqual(mergedBook.dateAdded, existingBook.dateAdded)
    XCTAssertEqual(mergedBook.readingHistory, readingHistory)
  }
}
