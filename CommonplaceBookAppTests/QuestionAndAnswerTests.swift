// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBookApp
import MiniMarkdown
import XCTest

private let simpleExample = """
# Sample file

Q: Why did I make this file?
A: To show how to create Q&A cards.

Q: Will it have _other_ content?
A: Yes! Just to make sure it **works**.

> And lo, it worked.
"""

final class QuestionAndAnswerTests: XCTestCase {
  func testParseSimpleExample() {
    let nodes = ParsingRules.commonplace.parse(simpleExample)
    XCTAssertEqual(nodes.count, 7)
    let boldWorlds = nodes[4].children[1].children[2]
    XCTAssertEqual(boldWorlds.type, .bold)
    XCTAssertEqual(boldWorlds.allMarkdown, "**works**")
  }

  func testParseOnlyQuestionAndAnswer() {
    let text = """
    Q: Is this a question?
    A: Yes.
    """
    let nodes = ParsingRules.commonplace.parse(text)
    XCTAssertEqual(nodes.count, 1)
    XCTAssertEqual(nodes[0].type, .questionAndAnswer)
  }
}
