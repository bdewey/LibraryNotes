// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GrailDiary
import TextMarkupKit
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
    let buffer = ParsedString(simpleExample, grammar: MiniMarkdownGrammar.shared)
    guard let tree = try? buffer.result.get() else {
      XCTFail("Should parse!")
      return
    }
    print(tree.debugDescription(withContentsFrom: simpleExample))
    XCTAssertEqual(
      tree.compactStructure,
      "(document (header delimiter tab text) blank_line (question_and_answer (qna_delimiter text tab) (qna_question text) (qna_delimiter text tab) (qna_answer text) text) blank_line (question_and_answer (qna_delimiter text tab) (qna_question text (emphasis delimiter text delimiter) text) (qna_delimiter text tab) (qna_answer text (strong_emphasis delimiter text delimiter) text) text) blank_line (blockquote (delimiter text tab) (paragraph text)))"
    )
  }
}
