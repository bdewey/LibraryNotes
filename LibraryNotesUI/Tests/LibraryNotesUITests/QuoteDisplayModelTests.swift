// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
@testable import LibraryNotesUI
import XCTest

final class QuoteDisplayModelTests: XCTestCase {
  func testOneWordChapterAndVerseCombinesWithTitle() {
    let model = QuoteDisplayModel(AttributedQuote(
      noteId: "note",
      key: "quote",
      text: "The answer is not in the back of the book. (80)",
      title: "Thinking Fast and Slow",
      thumbnailImage: nil
    ))

    XCTAssertEqual(model.quoteText, "The answer is not in the back of the book.")
    XCTAssertEqual(model.attributionText, "Thinking Fast and Slow, 80")
  }

  func testMultiWordAttributionFragmentReplacesTitle() {
    let model = QuoteDisplayModel(AttributedQuote(
      noteId: "note",
      key: "quote",
      text: "There are no binding oaths between men and lions. (The Iliad 22.310)",
      title: "The Iliad",
      thumbnailImage: nil
    ))

    XCTAssertEqual(model.quoteText, "There are no binding oaths between men and lions.")
    XCTAssertEqual(model.attributionText, "The Iliad 22.310")
  }

  func testNoChapterAndVerseFallsBackToTitle() {
    let model = QuoteDisplayModel(AttributedQuote(
      noteId: "note",
      key: "quote",
      text: "A quote without a source suffix.",
      title: "Collected Notes",
      thumbnailImage: nil
    ))

    XCTAssertEqual(model.quoteText, "A quote without a source suffix.")
    XCTAssertEqual(model.attributionText, "Collected Notes")
  }

  func testNoChapterAndVerseAndNoTitleUsesEmptyAttribution() {
    let model = QuoteDisplayModel(AttributedQuote(
      noteId: "note",
      key: "quote",
      text: "A quote without a source suffix.",
      title: "",
      thumbnailImage: nil
    ))

    XCTAssertEqual(model.quoteText, "A quote without a source suffix.")
    XCTAssertEqual(model.attributionText, "")
  }
}
