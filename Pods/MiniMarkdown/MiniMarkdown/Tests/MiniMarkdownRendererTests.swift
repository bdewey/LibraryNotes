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

import MiniMarkdown
import XCTest

final class MiniMarkdownRendererTests: XCTestCase {

  private static let formatters: [NodeType: RenderedMarkdown.FormattingFunction] = {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.heading] = { $1.fontSize = 24 }
    formatters[.list] = { $1.listLevel += 1 }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic = true }
    return formatters
  }()

  private static let renderers: [NodeType: RenderedMarkdown.RenderFunction] = {
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.listItem] = { (_, attributes) in
      return NSAttributedString(string: "*\t", attributes: attributes.attributes)
    }
    renderers[.image] = { (_, _) in
      let attachment = NSTextAttachment()
      return NSAttributedString(attachment: attachment)
    }
    return renderers
  }()

  private let renderedMarkdown = RenderedMarkdown(
    parsingRules: ParsingRules(),
    formatters: MiniMarkdownRendererTests.formatters,
    renderers: MiniMarkdownRendererTests.renderers
  )

  func testRenderWholeEnchilada() {
    let text = """
# Heading

This is text with *emphasis* and **bold.**

- I have a list
- With multiple items

And now I have text with an inline image ![alt text](assets/image.png) and **more stuff.**

"""

    renderedMarkdown.markdown = text
    XCTAssertEqual(renderedMarkdown.markdown, text)
    let (headingAttributes, headingRange) = renderedMarkdown.attributedString.attributesAndRange(at: 0)
    XCTAssertEqual(headingRange, NSRange(location: 0, length: 10))
    XCTAssertEqual(headingAttributes.font, renderedMarkdown.expectedAttributes(for: .heading).font)
    let (boldAttributes, boldRange) = renderedMarkdown.attributesAndRange(at: 47)
    XCTAssertEqual(boldRange, NSRange(location: 44, length: 9))
    XCTAssertEqual(boldAttributes.font, renderedMarkdown.expectedAttributes(for: .bold).font)
    let (lastAttributes, lastRange) = renderedMarkdown.attributesAndRange(
      at: renderedMarkdown.attributedString.length - 2
    )
    XCTAssertEqual(lastAttributes.font, renderedMarkdown.expectedAttributes(for: .bold).font)
    XCTAssertEqual(lastRange, NSRange(location: 141, length: 15))
  }

  func testRenderWithNestedLists() {
    let text = """
* This is the first list item.
  This is part of the same paragraph.

  This is a new paragraph that is part of the list item.

* This is the second list item in the same list.

  1. A nested ordered list.
  2. With multiple items.

And back to a normal paragraph outside the list.
"""

    renderedMarkdown.markdown = text
    XCTAssertEqual(renderedMarkdown.markdown, text)
  }

  func testLocationTranslation() {
    renderedMarkdown.markdown = "![alt text](assets/image.png)"
    XCTAssertEqual(0, renderedMarkdown.markdownLocation(for: 0))
    XCTAssertEqual(29, renderedMarkdown.markdownLocation(for: 1))
  }

  func testSimpleReplacement() {
    renderedMarkdown.markdown = "This is plain text."
    let range = renderedMarkdown.replaceCharacters(
      in: NSRange(location: 8, length: 5),
      with: "awesome"
    )
    XCTAssertEqual(renderedMarkdown.markdown, "This is awesome text.")
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 21))
  }

  func testAddingTextRerenders() {
    renderedMarkdown.markdown = "This is *plain text."
    XCTAssertEqual(
      renderedMarkdown.attributesAndRange(at: 10).0.font,
      renderedMarkdown.expectedAttributes(for: .text).font
    )
    let range = renderedMarkdown.replaceCharacters(
      in: NSRange(location: 14, length: 0),
      with: "*"
    )
    XCTAssertEqual(renderedMarkdown.markdown, "This is *plain* text.")
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 21))
    XCTAssertEqual(
      renderedMarkdown.attributesAndRange(at: 10).0.font,
      renderedMarkdown.expectedAttributes(for: .emphasis).font
    )
  }

  func testCanModifyTextAfterAnImage() {
    renderedMarkdown.markdown = "This text has an ![image](assets/image.png) which is *awesome*"
    let renderedString = renderedMarkdown.attributedString.string
    let range = NSRange(renderedString.range(of: "awesome")!, in: renderedString)
    let changedAttributesRange = renderedMarkdown.replaceCharacters(in: range, with: "super")
    XCTAssertEqual(changedAttributesRange.changedAttributesRange, NSRange(location: 0, length: 35))
    XCTAssertEqual(
      renderedMarkdown.markdown,
      "This text has an ![image](assets/image.png) which is *super*"
    )
  }

  func testEditFirstParagraph() {
    let text = """
First paragraph.

Second paragraph.
"""
    renderedMarkdown.markdown = text
    let replaceRange = NSRange(location: 0, length: 5)
    let range = renderedMarkdown.replaceCharacters(
      in: replaceRange,
      with: "Fantastic"
    )
    var expectedText = text
    expectedText.replaceSubrange(Range(replaceRange, in: expectedText)!, with: "Fantastic")
    XCTAssertEqual(renderedMarkdown.markdown, expectedText)
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 21))
  }

  func testEditSecondParagraph() {
    let text = """
First paragraph with image: ![alt text](assets/image.png).

Second paragraph.
"""
    renderedMarkdown.markdown = text
    let renderedString = renderedMarkdown.attributedString.string
    let replaceRange = NSRange(renderedString.range(of: "Second")!, in: renderedString)
    let range = renderedMarkdown.replaceCharacters(
      in: replaceRange,
      with: "Fantastic"
    )
    var expectedText = text
    expectedText.replaceSubrange(text.range(of: "Second")!, with: "Fantastic")
    XCTAssertEqual(renderedMarkdown.markdown, expectedText)
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 32, length: 20))
  }

  func testEditsCanCombineParagraphs() {
    let text = """
First paragraph with image: ![alt text](assets/image.png).

Second paragraph.
"""
    renderedMarkdown.markdown = text
    let renderedString = renderedMarkdown.attributedString.string
    let paragraphBoundary = NSRange(renderedString.range(of: "\n\n")!, in: renderedString)
    let range = renderedMarkdown.replaceCharacters(in: paragraphBoundary, with: "\n")
    let expectedText = """
First paragraph with image: ![alt text](assets/image.png).
Second paragraph.
"""
    XCTAssertEqual(renderedMarkdown.markdown, expectedText)
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 48))
  }

  func testEditsCanSplitParagraphs() {
    let text = """
First paragraph with image: ![alt text](assets/image.png).
Second paragraph.
"""
    renderedMarkdown.markdown = text
    let renderedString = renderedMarkdown.attributedString.string
    let paragraphBoundary = NSRange(renderedString.range(of: "\n")!, in: renderedString)
    let range = renderedMarkdown.replaceCharacters(in: paragraphBoundary, with: "\n\n")
    let expectedText = """
First paragraph with image: ![alt text](assets/image.png).

Second paragraph.
"""
    XCTAssertEqual(renderedMarkdown.markdown, expectedText)
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 49))
  }

  func testAppendingSimpleText() {
    renderedMarkdown.markdown = "This is text."
    let range = renderedMarkdown.replaceCharacters(
      in: NSRange(location: 13, length: 0),
      with: " More text."
    )
    XCTAssertEqual(renderedMarkdown.markdown, "This is text. More text.")
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 24))
  }

  func testAppendingToEmpty() {
    renderedMarkdown.markdown = ""
    let range = renderedMarkdown.replaceCharacters(
      in: NSRange(location: 0, length: 0),
      with: "Hello, world."
    )
    XCTAssertEqual(renderedMarkdown.markdown, "Hello, world.")
    XCTAssertEqual(range.changedAttributesRange, NSRange(location: 0, length: 13))
  }

  func testDeletingEverything() {
    renderedMarkdown.markdown = "This is some text."
    let range = renderedMarkdown.replaceCharacters(
      in: NSRange(location: 0, length: 18),
      with: ""
    )
    XCTAssertEqual("", renderedMarkdown.markdown)
    XCTAssertEqual(NSRange(location: 0, length: 0), range.changedAttributesRange)
  }

  func testChangeHeadingToHashtag() {
    renderedMarkdown.markdown = "# Heading"
    let range = renderedMarkdown.replaceCharacters(in: NSRange(location: 1, length: 1), with: "")
    XCTAssertEqual("#Heading", renderedMarkdown.markdown)
    XCTAssertEqual(NSRange(location: 0, length: 8), range.changedAttributesRange)
  }


  func testCompleteTheImageSequence() {
    renderedMarkdown.markdown = "![alt text](assets/image.png)"
    XCTAssertEqual(renderedMarkdown.attributedString.string.count, 1)
  }
}

extension NSAttributedString {
  func attributesAndRange(
    at location: Int
  ) -> ([NSAttributedString.Key: Any], NSRange) {
    var range = NSRange(location: NSNotFound, length: 0)
    let attributes = self.attributes(at: location, effectiveRange: &range)
    return (attributes, range)
  }
}

extension RenderedMarkdown {
  func expectedAttributes(for nodeType: NodeType) -> [NSAttributedString.Key: Any] {
    var attributes = defaultAttributes
    formatters[nodeType]?(Node(type: nodeType, slice: StringSlice("")), &attributes)
    return attributes.attributes
  }
}
