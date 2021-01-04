// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import XCTest

final class StringProtocolHashtagTests: XCTestCase {
  func testPathPrefixes() {
    XCTAssertTrue("book".isPathPrefix(of: "book"))
    XCTAssertTrue("book".isPathPrefix(of: "book/2020"))
    XCTAssertFalse("book/2020".isPathPrefix(of: "book"))
    XCTAssertFalse("book".isPathPrefix(of: "books"))
  }
}
