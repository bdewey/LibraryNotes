// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GrailDiary
import XCTest

private func formatTab(
  node: SyntaxTreeNode,
  startIndex: Int,
  buffer: SafeUnicodeBuffer,
  attributes: inout AttributedStringAttributesDescriptor
) -> [unichar] {
  return Array("\t".utf16)
}

final class ParsedAttributedStringTests: XCTestCase {
  func testReplacementsAffectStringsButNotRawText() {
    let formattingFunctions: [SyntaxTreeNodeType: QuickFormatFunction] = [
      .emphasis: { $1.italic = true },
      .header: { $1.fontSize = 24 },
      .list: { $1.listLevel += 1 },
      .strongEmphasis: { $1.bold = true },
    ]
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)

    let textStorage = ParsedAttributedString(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      quickFormatFunctions: formattingFunctions,
      fullFormatFunctions: [.softTab: formatTab]
    )

    textStorage.append(NSAttributedString(string: "# This is a heading\n\nAnd this is a paragraph"))
    XCTAssertEqual(textStorage.string, "#\tThis is a heading\n\nAnd this is a paragraph")
    XCTAssertEqual(textStorage.rawString.string, "# This is a heading\n\nAnd this is a paragraph")
  }

  func testVariableLengthReplacements() {
    let noDelimiterTextStorage = Self.makeNoDelimiterStorage()
    noDelimiterTextStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "#### This is a heading")
    XCTAssertEqual(noDelimiterTextStorage.string, "\tThis is a heading")
    XCTAssertEqual(noDelimiterTextStorage.rawStringRange(forRange: NSRange(location: 0, length: 18)), NSRange(location: 0, length: 22))
    XCTAssertEqual(noDelimiterTextStorage.rawStringRange(forRange: NSRange(location: 0, length: 1)), NSRange(location: 0, length: 5))
    XCTAssertEqual(noDelimiterTextStorage.range(forRawStringRange: NSRange(location: 0, length: 5)), NSRange(location: 0, length: 1))
    XCTAssertEqual(noDelimiterTextStorage.range(forRawStringRange: NSRange(location: 5, length: 1)), NSRange(location: 1, length: 1))

    // Walk through the string, attribute by attribute. We should end exactly at the end location.
    var location = 0
    var effectiveRange: NSRange = .init(location: 0, length: 0)
    while location < noDelimiterTextStorage.length {
      _ = noDelimiterTextStorage.attributes(at: location, effectiveRange: &effectiveRange)
      XCTAssert(
        location + effectiveRange.length <= noDelimiterTextStorage.string.utf16.count,
        "End of effective range (\(location + effectiveRange.length)) is beyond end-of-string \(noDelimiterTextStorage.string.utf16.count)"
      )
      print(effectiveRange)
      location += effectiveRange.length
    }
  }

  func testQandACardWithReplacements() {
    let markdown = "Q: Can Q&A cards have *formatting*?\nA: **Yes!** Even `code`!"
    let noDelimiterTextStorage = Self.makeNoDelimiterStorage()
    noDelimiterTextStorage.append(NSAttributedString(string: markdown))

    XCTAssertEqual(markdown.count - 8, noDelimiterTextStorage.count)
  }

  static func makeNoDelimiterStorage() -> ParsedAttributedString {
    let formattingFunctions: [SyntaxTreeNodeType: QuickFormatFunction] = [
      .emphasis: { $1.italic = true },
      .header: { $1.fontSize = 24 },
      .list: { $1.listLevel += 1 },
      .strongEmphasis: { $1.bold = true },
    ]
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)
    return ParsedAttributedString(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      quickFormatFunctions: formattingFunctions,
      fullFormatFunctions: [
        .softTab: formatTab,
        .delimiter: { _, _, _, _ in [] },
      ]
    )
  }
}
