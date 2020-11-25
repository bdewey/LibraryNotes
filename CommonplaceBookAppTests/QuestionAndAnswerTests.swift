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
