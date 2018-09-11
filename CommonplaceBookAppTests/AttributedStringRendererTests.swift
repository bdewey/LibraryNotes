// Copyright © 2018 Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
import MiniMarkdown
import XCTest

private let renderer: MarkdownFixer = {
  var renderer = MarkdownFixer()
  renderer.fixupsForNode[.listItem] = { (listItem) in
    if let firstWhitespaceIndex = listItem.slice.substring.firstIndex(where: { $0.isWhitespace }),
       listItem.slice.substring[firstWhitespaceIndex] != "\t" {
      let nsRange = NSRange(
        firstWhitespaceIndex ... firstWhitespaceIndex,
        in: listItem.slice.string
      )
      return [NSMutableAttributedString.Fixup(
        range: nsRange,
        newString: NSAttributedString(string: "\t")
        ), ]
    }
    return []
  }
  return renderer
}()

final class AttributedStringRendererTests: XCTestCase {

  func testRoundTripList() {
    let markdown = """
- Item 1
- Item 2
"""
    let fixed = """
-\tItem 1
-\tItem 2
"""
    let rendered = renderer.attributedStringWithFixups(from: markdown)
    XCTAssertEqual(rendered.string, fixed)
    XCTAssertEqual(rendered.stringWithoutFixups, markdown)
  }

  func testRoundTripAfterEdits() {
    let markdown = """
- Item 1
- Item 2
"""
    let fixed = """
-\tItem one
-\tItem 2
"""
    let withoutFixups = """
- Item one
- Item 2
"""
    let rendered = renderer
      .attributedStringWithFixups(from: markdown)
      .mutableCopy() as! NSMutableAttributedString // swiftlint:disable:this force_cast
    let change = RangeReplaceableChange(range: NSRange(location: 7, length: 1), newElements: "one")
    rendered.applyChange(change)
    XCTAssertEqual(rendered.string, fixed)
    XCTAssertEqual(rendered.stringWithoutFixups, withoutFixups)
  }

  func testFixupsSurviveSyntaxHighlighting() {
    let markdown = """
- Item 1
- Item 2
"""
    let fixed = """
-\tItem one
-\tItem 2
"""
    let withoutFixups = """
- Item one
- Item 2
"""
    let rendered = renderer
      .attributedStringWithFixups(from: markdown)
      .mutableCopy() as! NSMutableAttributedString // swiftlint:disable:this force_cast
    let stylesheet = AttributedStringStylesheet()
    let baseAttributes = NSAttributedString.Attributes(UIFont.systemFont(ofSize: 14))
    // swiftlint:disable:next force_try
    try! rendered.applySyntaxHighlighting(
      to: rendered.string.startIndex ..< rendered.string.endIndex,
      baseAttributes: baseAttributes,
      stylesheet: stylesheet,
      parsingRules: ParsingRules()
    )
    let change = RangeReplaceableChange(range: NSRange(location: 7, length: 1), newElements: "one")
    rendered.applyChange(change)
    XCTAssertEqual(rendered.string, fixed)
    XCTAssertEqual(rendered.stringWithoutFixups, withoutFixups)
  }
}
