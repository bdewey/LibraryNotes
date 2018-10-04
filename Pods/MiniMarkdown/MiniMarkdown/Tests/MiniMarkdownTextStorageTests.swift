// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import CocoaLumberjack
@testable import MiniMarkdown

private let initializeLogging: Void = {
  DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console
}()

final class MiniMarkdownTextStorageTests: XCTestCase {
  
  var textStorage: MiniMarkdownTextStorage!
  var delegateMessages: [DelegateMessage] = []
  
  override func setUp() {
    initializeLogging
    super.setUp()

    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.heading] = { $1.fontSize = 24 }
    formatters[.list] = { $1.listLevel += 1 }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic = true }

    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.listItem] = { (_, attributes) in
      return NSAttributedString(string: "\u{2022}\t", attributes: attributes.attributes)
    }
    renderers[.image] = { (_, attributes) in
      let attachment = NSTextAttachment()
      return NSAttributedString(attachment: attachment)
    }

    textStorage = MiniMarkdownTextStorage(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
    textStorage.delegate = self
    delegateMessages = []
  }
  
  func testPlainTextHasPlainAttributes() {
    textStorage.append(NSAttributedString(string: "Plain text"))
    XCTAssertEqual(textStorage.length, 10)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    let expectedFont = textStorage.defaultAttributes.attributes[.font] as! UIFont
    XCTAssertEqual(actualFont, expectedFont)
    XCTAssertEqual(range, NSRange(location: 0, length: 10))
    XCTAssertEqual(delegateMessages.count, 2)
    XCTAssertEqual(delegateMessages[0].editedRange, NSRange(location: 0, length: 10))
    XCTAssertEqual(delegateMessages[0].changeInLength, 10)
  }

  func testBaseTextStorage() {
    let storage = NSTextStorage()
    storage.delegate = self
    storage.append(NSAttributedString(string: "Plain text"))
    XCTAssertEqual(delegateMessages.count, 2)
  }
  
  func testHeadingTextHasHeadingAttributes() {
    textStorage.append(NSAttributedString(string: "# Heading"))
    XCTAssertEqual(textStorage.length, 9)
    var range = NSRange(location: NSNotFound, length: 0)
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range).font
    let expectedFont = textStorage.expectedAttributes(for: .heading).font
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
    let actualFont = textStorage.attributes(at: 0, effectiveRange: &range).font
    let expectedFont = textStorage.expectedAttributes(for: .heading).font
    XCTAssertEqual(actualFont, expectedFont)
    let headingRange = NSRange(location: 0, length: 10)
    XCTAssertEqual(range, headingRange)
    textStorage.append(NSAttributedString(string: "\n- list\n"))
    let doubleCheckFont = textStorage.attributes(at: 0, effectiveRange: &range)[.font] as! UIFont
    XCTAssertEqual(doubleCheckFont, expectedFont)
    XCTAssertEqual(range, headingRange)
  }

  func testCompleteTheImage() {
    textStorage.append(NSAttributedString(string: "![alt text](assets.image.png"))
    textStorage.append(NSAttributedString(string: ")"))
    XCTAssertEqual(textStorage.string.count, 1)
    XCTAssertEqual(delegateMessages.count, 4)
  }

  func testStartWithImage() {
    textStorage.append(NSAttributedString(string: "![alt text](assets.image.png)"))
    XCTAssertEqual(textStorage.string.count, 1)
    XCTAssertEqual(delegateMessages.count, 2)
  }

  func testRoundTripTable() {
    let text = """
| Spanish                  | Engish                                                              |
| ------------------------ | ------------------------------------------------------------------- |
| tenedor                  | fork                                                                |
| hombre                   | man                                                                 |
| mujer                    | woman                                                               |
| niño                     | boy                                                                 |
| niña                     | girl                                                                |

"""
    textStorage.markdown = text
    XCTAssertEqual(text, textStorage.markdown)
  }

  func testAppendAfterTable() {
    let text = """
| Spanish                  | Engish                                                              |
| ------------------------ | ------------------------------------------------------------------- |
| tenedor                  | fork                                                                |
| hombre                   | man                                                                 |
| mujer                    | woman                                                               |
| niño                     | boy                                                                 |
| niña                     | girl                                                                |

"""
    textStorage.markdown = text
    textStorage.append(NSAttributedString(string: "Hello, world\n"))
    XCTAssertEqual(text + "Hello, world\n", textStorage.markdown)
  }
}

extension MiniMarkdownTextStorageTests: NSTextStorageDelegate {
  struct DelegateMessage: Equatable {
    let message: String
    let editedMask: NSTextStorage.EditActions
    let editedRange: NSRange
    let changeInLength: Int
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    willProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    delegateMessages.append(
      DelegateMessage(
        message: "willProcessEditing",
        editedMask: editedMask,
        editedRange: editedRange,
        changeInLength: delta
      )
    )
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    delegateMessages.append(
      DelegateMessage(
        message: "didProcessEditing",
        editedMask: editedMask,
        editedRange: editedRange,
        changeInLength: delta
      )
    )
  }
}
