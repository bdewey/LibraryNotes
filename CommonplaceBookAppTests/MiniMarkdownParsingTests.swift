//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import CommonplaceBookApp
import XCTest

final class MiniMarkdownParsingTests: XCTestCase {
  func testNothingButText() {
    parseText("Just text.", expectedStructure: "(document (paragraph text))")
  }

  func testHeaderAndBody() {
    let markdown = """
    # This is a header

    And this is a body.
    The two lines are part of the same paragraph.

    The line break indicates a new paragraph.

    """
    parseText(
      markdown,
      expectedStructure: "(document (header delimiter tab text) blank_line (paragraph text) blank_line (paragraph text))"
    )
  }

  func testJustEmphasis() {
    parseText(
      "*This is emphasized text.*",
      expectedStructure: "(document (paragraph (emphasis delimiter text delimiter)))"
    )
  }

  func testTextWithEmphasis() {
    parseText(
      "This is text with *emphasis.*",
      expectedStructure: "(document (paragraph text (emphasis delimiter text delimiter)))"
    )
  }

  func testWithBold() {
    parseText(
      "This is text with **bold**.",
      expectedStructure: "(document (paragraph text (strong_emphasis delimiter text delimiter) text))"
    )
  }

  func testTextAndHeader() {
    parseText(
      "Text\n# Heading",
      expectedStructure: "(document (paragraph text) (header delimiter tab text))"
    )
  }

  func testTextAndCode() {
    parseText(
      "This is text with `code`.",
      expectedStructure: "(document (paragraph text (code delimiter text delimiter) text))"
    )
  }

  func testParagraphs() {
    parseText(
      "Paragraph\n\nX",
      expectedStructure: "(document (paragraph text) blank_line (paragraph text))"
    )
  }

  func testListWithMultipleItems() {
    let markdown = """
    - Item one
    - Item two
    """
    parseText(markdown, expectedStructure: "(document (list (list_item (delimiter unordered_list_opening tab) (paragraph text)) (list_item (delimiter unordered_list_opening tab) (paragraph text))))")
  }

  func testListItemWithStyling() {
    parseText(
      "- This is a list item with **strong emphasis**",
      expectedStructure: "(document (list (list_item (delimiter unordered_list_opening tab) (paragraph text (strong_emphasis delimiter text delimiter)))))"
    )
  }

  func testEmphasisDoesNotSpanListItems() {
    let markdown = """
    - Item *one
    - Item *two
    """
    parseText(markdown, expectedStructure: "(document (list (list_item (delimiter unordered_list_opening tab) (paragraph text)) (list_item (delimiter unordered_list_opening tab) (paragraph text))))")
  }

  func testAllUnorderedListMarkers() {
    let example = """
    - This is a list item.
    + So is this.
    * And so is this.

    """
    let tree = parseText(example, expectedStructure: "(document (list (list_item (delimiter unordered_list_opening tab) (paragraph text)) (list_item (delimiter unordered_list_opening tab) (paragraph text)) (list_item (delimiter unordered_list_opening tab) (paragraph text))))")
    XCTAssertEqual(tree?.node(at: [0])?[ListTypeKey.self], .unordered)
  }

  func testOrderedListMarkers() {
    let example = """
    1. this is the first item
    2. this is the second item
    3) This is also legit.

    """
    let tree = parseText(example, expectedStructure: "(document (list (list_item (delimiter ordered_list_number ordered_list_terminator tab) (paragraph text)) (list_item (delimiter ordered_list_number ordered_list_terminator tab) (paragraph text)) (list_item (delimiter ordered_list_number ordered_list_terminator tab) (paragraph text))))")
    XCTAssertEqual(tree?.node(at: [0])?[ListTypeKey.self], .ordered)
  }

  func testSingleLineBlockQuote() {
    let example = "> This is a quote with **bold** text."
    parseText(example, expectedStructure: "(document (blockquote delimiter (paragraph text (strong_emphasis delimiter text delimiter) text)))")
  }

  func testOrderedMarkerCannotBeTenDigits() {
    let example = """
    12345678900) This isn't a list.
    """
    parseText(example, expectedStructure: "(document (paragraph text))")
  }

  func testParseHashtag() {
    parseText("#hashtag\n", expectedStructure: "(document (paragraph hashtag text))")
  }

  func testParseHashtagInText() {
    parseText("Paragraph with #hashtag\n", expectedStructure: "(document (paragraph text hashtag text))")
  }

  func testHashtagCannotStartInTheMiddleOfAWord() {
    let example = "This paragraph does not contain a#hashtag because there is no space at the start."
    parseText(example, expectedStructure: "(document (paragraph text))")
  }

  func testParseImages() {
    let example = "This text has an image reference: ![xkcd](https://imgs.xkcd.com/comics/october_30th.png)"
    parseText(example, expectedStructure: "(document (paragraph text image))")
  }

  func testUnderlineEmphasis() {
    parseText("Underlines can do _emphasis_.", expectedStructure: "(document (paragraph text (emphasis delimiter text delimiter) text))")
  }

  func testLeftFlanking() {
    parseText(
      "This is * not* emphasis because the star doesn't hug",
      expectedStructure: "(document (paragraph text))"
    )
  }

  func testRightFlanking() {
    parseText(
      "This is *not * emphasis because the star doesn't hug",
      expectedStructure: "(document (paragraph text))"
    )
  }

  func testTypingBugText() {
    // Note that we currently coalesce consecutive blank_line nodes into a single blank_line node,
    // the same as with consecutive text nodes. This isn't obvious and I'm not sure I like it
    // but I'm going to let it be for now.
    parseText(
      "# Welcome to Scrap Paper.\n\n\n\n## Second heading\n\n",
      expectedStructure: "(document (header delimiter tab text) blank_line (header delimiter tab text) blank_line)"
    )
  }

  func testFile() {
    let pieceTable = PieceTable(TestStrings.markdownCanonical)
    let memoizationTable = MemoizationTable(grammar: MiniMarkdownGrammar.shared)
    do {
      _ = try memoizationTable.parseBuffer(pieceTable)
    } catch {
      XCTFail("Unexpected error: \(error)")
      print(TraceBuffer.shared)
    }
  }
}

// MARK: - Private

private extension MiniMarkdownParsingTests {
  @discardableResult
  func parseText(_ text: String, expectedStructure: String, file: StaticString = #file, line: UInt = #line) -> NewNode? {
    do {
      let pieceTable = PieceTable(text)
      let memoizationTable = MemoizationTable(grammar: MiniMarkdownGrammar.shared)
      let tree = try memoizationTable.parseBuffer(pieceTable)
      if tree.length != pieceTable.count {
        let unparsedText = pieceTable[NSRange(location: tree.length, length: pieceTable.count - tree.length)]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'", file: file, line: line)
      }
      if expectedStructure != tree.compactStructure {
        print("### Failure: \(name)")
        print("Got:      " + tree.compactStructure)
        print("Expected: " + expectedStructure)
        print("\n")
        print(tree.debugDescription(withContentsFrom: pieceTable))
        print("\n\n\n")
      }
      XCTAssertEqual(tree.compactStructure, expectedStructure, "Unexpected structure", file: file, line: line)
      return tree
    } catch {
      XCTFail("Unexpected error: \(error)", file: file, line: line)
      return nil
    }
  }
}
