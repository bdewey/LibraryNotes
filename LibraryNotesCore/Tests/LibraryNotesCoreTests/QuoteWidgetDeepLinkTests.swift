// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
@testable import LibraryNotesCore
import XCTest

final class QuoteWidgetDeepLinkTests: XCTestCase {
  func testRoundTripPreservesIdentifiers() throws {
    let link = try QuoteWidgetDeepLink(noteId: "note id/with punctuation", quoteKey: "quote&key")

    XCTAssertEqual(try QuoteWidgetDeepLink(url: link.url), link)
    XCTAssertEqual(link.url.scheme, "dogeared")
    XCTAssertEqual(link.url.host, "quote-of-the-day")
  }

  func testRejectsOtherRoutes() throws {
    let url = try XCTUnwrap(URL(string: "dogeared://another-route?noteId=note&quoteKey=quote"))

    XCTAssertThrowsError(try QuoteWidgetDeepLink(url: url)) { error in
      XCTAssertEqual(error as? QuoteWidgetDeepLinkError, .invalidRoute)
    }
  }

  func testRejectsMissingIdentifiers() throws {
    let url = try XCTUnwrap(URL(string: "dogeared://quote-of-the-day?noteId=note"))

    XCTAssertThrowsError(try QuoteWidgetDeepLink(url: url)) { error in
      XCTAssertEqual(error as? QuoteWidgetDeepLinkError, .missingQuoteIdentifier)
    }
  }
}
