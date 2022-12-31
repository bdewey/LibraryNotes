// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Library_Notes
import XCTest

final class NSAttributedString_MiniMarkdownTests: XCTestCase {
  func testRemoveBlankLinksBetweenParagraphs() {
    let miniMarkdown = """
    This is the first paragraph.

    And this is the second paragraph.
    """
    let attributedString = NSAttributedString(miniMarkdown: miniMarkdown)
    XCTAssertEqual(attributedString.string, "This is the first paragraph.\nAnd this is the second paragraph.")
    XCTAssertEqual(attributedString.makeMiniMarkdown(), miniMarkdown)
  }

  func testSoftNewlinesInParagraphsAreRemoved() {
    let miniMarkdown = """
    This is the first paragraph.
    This is part of the first paragraph.

    And this is the second paragraph.
    """
    let attributedString = NSAttributedString(miniMarkdown: miniMarkdown)
    XCTAssertEqual(attributedString.string, "This is the first paragraph. This is part of the first paragraph.\nAnd this is the second paragraph.")
    XCTAssertEqual(attributedString.makeMiniMarkdown(), "This is the first paragraph. This is part of the first paragraph.\n\nAnd this is the second paragraph.")
  }

  func testSimpleInlineFormatting() {
    let miniMarkdown = "This string has **bold** and *italic* text."
    let attributedString = NSAttributedString(miniMarkdown: miniMarkdown)
    XCTAssertEqual(attributedString.string, "This string has bold and italic text.")
    XCTAssertEqual(attributedString.makeMiniMarkdown(), "This string has **bold** and _italic_ text.")
  }
}
