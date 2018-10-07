// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import CocoaLumberjack
@testable import MiniMarkdown

private let initializeLogging: Void = {
  DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console
}()

fileprivate enum TextOperation {
  case append(text: String)
  case replace(range: NSRange, replacement: String)

  func apply(to textStorage: NSTextStorage) {
    switch self {
    case let .append(text: str):
      textStorage.append(NSAttributedString(string: str))
    case let .replace(range: range, replacement: replacement):
      textStorage.replaceCharacters(in: range, with: replacement)
    }
  }
}

fileprivate extension MiniMarkdownTextStorage {
  convenience override init() {
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

    self.init(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
  }
}

final class MiniMarkdownTextStorageTests: XCTestCase {
  
  var textStorage: MiniMarkdownTextStorage!

  override func setUp() {
    initializeLogging
    super.setUp()
    textStorage = MiniMarkdownTextStorage()
  }

  fileprivate static func validateDelegateMessagesMatch(for operations: [TextOperation]) {
    let miniMarkdownTextStorage = MiniMarkdownTextStorage()
    let miniMarkdownRecorder = TextStorageMessageRecorder()
    miniMarkdownTextStorage.delegate = miniMarkdownRecorder
    let plainTextStorage = NSTextStorage()
    let plainTextRecorder = TextStorageMessageRecorder()
    plainTextStorage.delegate = plainTextRecorder
    for operation in operations {
      operation.apply(to: miniMarkdownTextStorage)
      operation.apply(to: plainTextStorage)
    }
    XCTAssertEqual(
      miniMarkdownRecorder.delegateMessages,
      plainTextRecorder.delegateMessages
    )
    XCTAssertEqual(miniMarkdownTextStorage.string, plainTextStorage.string)
  }

  fileprivate static func validateDelegateMessages(
    for operations: [TextOperation],
    are expectedMessages: [TextStorageMessageRecorder.DelegateMessage]
  ) {
    let miniMarkdownTextStorage = MiniMarkdownTextStorage()
    let miniMarkdownRecorder = TextStorageMessageRecorder()
    miniMarkdownTextStorage.delegate = miniMarkdownRecorder
    let plainTextStorage = NSTextStorage()
    let plainTextRecorder = TextStorageMessageRecorder()
    plainTextStorage.delegate = plainTextRecorder
    for operation in operations {
      operation.apply(to: miniMarkdownTextStorage)
      operation.apply(to: plainTextStorage)
    }
    XCTAssertEqual(
      miniMarkdownRecorder.delegateMessages,
      expectedMessages
    )
    XCTAssertEqual(miniMarkdownTextStorage.string, plainTextStorage.string)
  }
  
  func testPlainTextHasPlainAttributes() {
    MiniMarkdownTextStorageTests.validateDelegateMessagesMatch(for: [.append(text: "Plain text")])
  }

  func testEmoji() {
    MiniMarkdownTextStorageTests.validateDelegateMessagesMatch(
      for: [.append(text: "Cool cats 😻😼🙀 are here")]
    )
  }

  func testEditEmoji() {
    MiniMarkdownTextStorageTests.validateDelegateMessages(
      for: [
        .append(text: "😻"),
        .replace(range: NSRange(location: 2, length: 0), replacement: " cat"),
      ],
      are: Array([
        TextStorageMessageRecorder.DelegateMessage.messagePair(
          editedMask: [.editedCharacters, .editedAttributes],
          editedRange: NSMakeRange(0, 2),
          changeInLength: 2
        ),
        TextStorageMessageRecorder.DelegateMessage.messagePair(
          editedMask: [.editedCharacters],
          editedRange: NSMakeRange(2, 4),
          changeInLength: 4
        ),
        TextStorageMessageRecorder.DelegateMessage.messagePair(
          editedMask: [.editedAttributes],
          editedRange: NSMakeRange(0, 6),
          changeInLength: 0
        ),
      ].joined())
    )
  }

  fileprivate func deleteEverything(from cocoaTextStorage: NSTextStorage) {
    cocoaTextStorage.append(NSAttributedString(string: "Hello world!"))
    XCTAssertEqual(12, cocoaTextStorage.length)
    cocoaTextStorage.replaceCharacters(in: NSRange(location: 0, length: 12), with: "")
    XCTAssertEqual(0, cocoaTextStorage.length)
  }

  func testDeleteEverything() {
    let miniMarkdownRecorder = TextStorageMessageRecorder()
    textStorage.delegate = miniMarkdownRecorder
    deleteEverything(from: textStorage)
    let cocoaTextStorage = NSTextStorage()
    let cocoaTextStorageRecorder = TextStorageMessageRecorder()
    cocoaTextStorage.delegate = cocoaTextStorageRecorder
    deleteEverything(from: cocoaTextStorage)
    XCTAssertEqual(
      miniMarkdownRecorder.delegateMessages,
      cocoaTextStorageRecorder.delegateMessages
    )
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
    let textStorageMessageRecorder = TextStorageMessageRecorder()
    textStorage.delegate = textStorageMessageRecorder
    textStorage.append(NSAttributedString(string: "![alt text](assets.image.png"))
    textStorage.append(NSAttributedString(string: ")"))
    XCTAssertEqual(textStorage.string.count, 1)
    XCTAssertEqual(textStorageMessageRecorder.delegateMessages.count, 4)
  }

  func testStartWithImage() {
    let textStorageMessageRecorder = TextStorageMessageRecorder()
    textStorage.delegate = textStorageMessageRecorder
    textStorage.append(NSAttributedString(string: "![alt text](assets.image.png)"))
    XCTAssertEqual(textStorage.string.count, 1)
    XCTAssertEqual(textStorageMessageRecorder.delegateMessages.count, 2)
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

internal final class TextStorageMessageRecorder: NSObject, NSTextStorageDelegate {
  struct DelegateMessage: Equatable {
    let message: String
    let editedMask: NSTextStorage.EditActions
    let editedRange: NSRange
    let changeInLength: Int

    static func messagePair(
      editedMask: NSTextStorage.EditActions,
      editedRange: NSRange,
      changeInLength: Int
    ) -> [DelegateMessage] {
      return ["willProcessEditing", "didProcessEditing"].map {
        return DelegateMessage(
          message: $0,
          editedMask: editedMask,
          editedRange: editedRange,
          changeInLength: changeInLength
        )
      }
    }
  }

  public var delegateMessages: [DelegateMessage] = []

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
