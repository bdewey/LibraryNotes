// Copyright © 2018 Brian's Brain. All rights reserved.

import MiniMarkdown
import XCTest

final class MarkdownStringRendererTests: XCTestCase {
  func testRenderEmphasis() {
    let nodes = ParsingRules().parse("Text with *emphasis*.")
    let text = MarkdownStringRenderer.textOnly.render(node: nodes[0])
    XCTAssertEqual("Text with emphasis.", text)
  }

  func testRenderBold() {
    let nodes = ParsingRules().parse("Text with **bold**.")
    let text = MarkdownStringRenderer.textOnly.render(node: nodes[0])
    XCTAssertEqual("Text with bold.", text)
  }

  func testRenderHeading() {
    let nodes = ParsingRules().parse("# Heading with **bold**")
    let text = MarkdownStringRenderer.textOnly.render(node: nodes[0])
    XCTAssertEqual("Heading with bold", text)
  }
}
