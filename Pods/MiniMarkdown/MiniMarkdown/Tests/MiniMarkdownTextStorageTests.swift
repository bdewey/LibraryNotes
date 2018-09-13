// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

@testable import MiniMarkdown

final class MiniMarkdownTextStorageTests: XCTestCase {
  
  var textStorage: MiniMarkdownTextStorage!
  
  override func setUp() {
    super.setUp()
    
    textStorage = MiniMarkdownTextStorage()
    textStorage.stylesheet[.heading] = { (_, attributes) in
      attributes.fontSize = 42
    }
    textStorage.stylesheet[.emphasis] = { (_, attributes) in
      attributes.italic = true
    }
  }
  
  func testPlainTextHasPlainAttributes() {
    textStorage.append(NSAttributedString(string: "Plain text"))
    XCTAssertEqual(textStorage.length, 10)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    let expectedFont = textStorage.defaultAttributes.attributes[.font] as! UIFont
    XCTAssertEqual(actualFont, expectedFont)
    XCTAssertEqual(range, NSRange(location: 0, length: 10))
  }
  
  func testHeadingTextHasHeadingAttributes() {
    textStorage.append(NSAttributedString(string: "# Heading"))
    XCTAssertEqual(textStorage.length, 9)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    var headingAttributes = textStorage.defaultAttributes
    textStorage.stylesheet[.heading]?(
      MiniMarkdown.Heading(slice: StringSlice("# Heading"), headingLevel: 1),
      &headingAttributes
    )
    let expectedFont = headingAttributes.attributes[.font] as! UIFont
    XCTAssertEqual(actualFont, expectedFont)
    XCTAssertEqual(range, NSRange(location: 0, length: 9))
  }
  
  func testDeleteHashAndNowPlainText() {
    textStorage.append(NSAttributedString(string: "# Heading"))
    textStorage.deleteCharacters(in: NSRange(location: 0, length: 2))
    XCTAssertEqual(textStorage.length, 7)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    let expectedFont = textStorage.defaultAttributes.attributes[.font] as! UIFont
    XCTAssertEqual(actualFont, expectedFont)
    XCTAssertEqual(range, NSRange(location: 0, length: 7))
  }
  
  func testTextWithEmphasis() {
    textStorage.append(NSAttributedString(string: "This text has *emphasis*, baby!"))
    var range = NSRange(location: NSNotFound, length: 0)
    let font = textStorage.attributes(at: 17, effectiveRange: &range)[.font] as! UIFont
    XCTAssert(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    XCTAssertEqual(range, NSRange(location: 14, length: 10))
  }

  func testListItemWithInlineFormatting() {
    textStorage.append(NSAttributedString(string: "- This list item has *emphasis*, baby!"))
    var range = NSRange(location: NSNotFound, length: 0)
    let font = textStorage.attributes(at: 23, effectiveRange: &range)[.font] as! UIFont
    XCTAssert(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    XCTAssertEqual(range, NSRange(location: 21, length: 10))
  }

  func testTurnItemIntoListPreservesFormatting() {
    textStorage.append(NSAttributedString(string: "This list item has *emphasis*, baby!"))
    textStorage.insert(NSAttributedString(string: "- "), at: 0)
    var range = NSRange(location: NSNotFound, length: 0)
    let font = textStorage.attributes(at: 23, effectiveRange: &range)[.font] as! UIFont
    XCTAssert(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    XCTAssertEqual(range, NSRange(location: 21, length: 10))
  }

  func testHeadingFollowedByList() {
    textStorage.append(NSAttributedString(string: "# Heading\n"))
    XCTAssertEqual(textStorage.length, 10)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    var headingAttributes = textStorage.defaultAttributes
    textStorage.stylesheet[.heading]?(
      Heading(slice: StringSlice("# Heading\n"), headingLevel: 1),
      &headingAttributes
    )
    let expectedFont = headingAttributes.attributes[.font] as! UIFont
    XCTAssertEqual(actualFont, expectedFont)
    let headingRange = NSRange(location: 0, length: 10)
    XCTAssertEqual(range, headingRange)
    textStorage.append(NSAttributedString(string: "\n- list\n"))
    let doubleCheckFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    XCTAssertEqual(doubleCheckFont, expectedFont)
    XCTAssertEqual(range, headingRange)
  }
}
