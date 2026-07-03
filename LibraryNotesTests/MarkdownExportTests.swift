// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

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
