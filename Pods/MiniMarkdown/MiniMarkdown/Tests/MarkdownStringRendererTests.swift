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

final class MarkdownAttributedStringRendererTests: XCTestCase {
  func testRenderEmphasis() {
    let nodes = ParsingRules().parse("Text with *emphasis*.")
    let text = MarkdownAttributedStringRenderer.textOnly.render(node: nodes[0]).string
    XCTAssertEqual("Text with emphasis.", text)
  }

  func testRenderBold() {
    let nodes = ParsingRules().parse("Text with **bold**.")
    let text = MarkdownAttributedStringRenderer.textOnly.render(node: nodes[0]).string
    XCTAssertEqual("Text with bold.", text)
  }

  func testRenderHeading() {
    let nodes = ParsingRules().parse("# Heading with **bold**")
    let text = MarkdownAttributedStringRenderer.textOnly.render(node: nodes[0]).string
    XCTAssertEqual("Heading with bold", text)
  }
}
