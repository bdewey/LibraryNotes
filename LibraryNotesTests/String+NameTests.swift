// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotes
import XCTest

final class StringNameTests: XCTestCase {
  func testBasics() {
    XCTAssertEqual("Brian Dewey".nameLastFirst(), "Dewey Brian")
    XCTAssertEqual("T. S. Eliot".nameLastFirst(), "Eliot T. S.")
    XCTAssertEqual("Brian Kenneth Dewey".nameLastFirst(), "Dewey Brian Kenneth")
    XCTAssertEqual("J. R. R. Tolkien".nameLastFirst(), "Tolkien J. R. R.")
    XCTAssertEqual("Gabriel García Marquez".nameLastFirst(), "García Marquez Gabriel")
    XCTAssertEqual("Eddie Van Halen".nameLastFirst(), "Van Halen Eddie")
  }
}
