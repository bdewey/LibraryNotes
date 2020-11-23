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

import CommonplaceBookApp
import Foundation
import XCTest

final class ParsedStringTests: XCTestCase {
  func testSimpleEdit() {
    let parser = ParsedString("Testing", grammar: MiniMarkdownGrammar())
    parser.replaceCharacters(in: NSRange(location: 7, length: 0), with: ", testing")
    validateParser(parser, has: "(document (paragraph text))")
  }

  func testInsertBold() {
    let parser = ParsedString("Hello world", grammar: MiniMarkdownGrammar())
    validateParser(parser, has: "(document (paragraph text))")
    parser.replaceCharacters(in: NSRange(location: 6, length: 0), with: "**awesome** ")
    validateParser(parser, has: "(document (paragraph text (strong_emphasis delimiter text delimiter) text))")
  }

  func testInsertCanChangeFormatting() {
    let parser = ParsedString("Hello **world*", grammar: MiniMarkdownGrammar())
    validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
    TraceBuffer.shared.traceEntries.removeAll()
    parser.replaceCharacters(in: NSRange(location: 14, length: 0), with: "*")
    print(parser.utf16String)
    validateParser(parser, has: "(document (paragraph text (strong_emphasis delimiter text delimiter)))")
  }

  func testDeleteCanChangeFormatting() {
    let parser = ParsedString("Hello * world*", grammar: MiniMarkdownGrammar())
    validateParser(parser, has: "(document (paragraph text))")
    TraceBuffer.shared.traceEntries.removeAll()
    parser.replaceCharacters(in: NSRange(location: 7, length: 1), with: "")
    XCTAssertEqual(parser.utf16String, parser.string)
    validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
  }

  func testDeleteCanChangeFormattingRightFlank() {
    let parser = ParsedString("Hello *world *", grammar: MiniMarkdownGrammar())
    validateParser(parser, has: "(document (paragraph text))")
    TraceBuffer.shared.traceEntries.removeAll()
    parser.replaceCharacters(in: NSRange(location: 12, length: 1), with: "")
    XCTAssertEqual(parser.utf16String, parser.string)
    validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
  }

  func testIncrementalParsingReusesNodesWhenPossible() {
    let text = """
    # Sample document

    I will be editing this **awesome** text and expect most nodes to be reused.
    """
    let parser = ParsedString(text, grammar: MiniMarkdownGrammar())
    guard let tree = validateParser(parser, has: "(document (header delimiter tab text) blank_line (paragraph text (strong_emphasis delimiter text delimiter) text))") else {
      XCTFail("Expected a tree")
      return
    }
    let emphasis = tree.node(at: [2, 1])
    XCTAssertEqual(emphasis?.type, .strongEmphasis)
    parser.replaceCharacters(in: NSRange(location: text.utf16.count, length: 0), with: "Change paragraph!\n\nAnd add a new one.")
    guard let editedTree = validateParser(parser, has: "(document (header delimiter tab text) blank_line (paragraph text (strong_emphasis delimiter text delimiter) text) blank_line (paragraph text))") else {
      XCTFail("Expected a tree")
      return
    }
    let editedEmphasis = editedTree.node(at: [2, 1])
    XCTAssertEqual(editedEmphasis?.type, .strongEmphasis)
    XCTAssert(emphasis === editedEmphasis)
  }

  func testAddSentenceToLargeText() {
    let largeText = String(repeating: TestStrings.markdownCanonical, count: 10)
    let parser = ParsedString(largeText, grammar: MiniMarkdownGrammar())
    let toInsert = "\n\nI'm adding some new text with *emphasis* to test incremental parsing.\n\n"
    measure {
      for (i, ch) in toInsert.utf16.enumerated() {
        let buf = [ch]
        let str = String(utf16CodeUnits: buf, count: 1)
        parser.replaceCharacters(in: NSRange(location: 34 + i, length: 0), with: str)
      }
    }
    print("Inserted \(toInsert.utf16.count) characters, so remember to divide for per-character costs")
  }
}

// MARK: - Private

private extension ParsedStringTests {
  @discardableResult
  func validateParser(_ parser: ParsedString, has expectedStructure: String, file: StaticString = #file, line: UInt = #line) -> NewNode? {
    do {
      let tree = try parser.result.get()
      if tree.length != parser.count {
        let unparsedText = parser[NSRange(location: tree.length, length: parser.count - tree.length)]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'", file: file, line: line)
      }
      if expectedStructure != tree.compactStructure {
        print("### Failure: \(name)")
        print("Got:      " + tree.compactStructure)
        print("Expected: " + expectedStructure)
        print("\n")
        print(tree.debugDescription(withContentsFrom: parser))
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
