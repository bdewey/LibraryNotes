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

@testable import CommonplaceBookApp
import XCTest

final class StringTypographyTests: XCTestCase {
  private let examples: [String: String] = [
    "--": "—",
    "No substitutions": "No substitutions",
    "\"This is a quote!\" he exclaimed.": "“This is a quote!” he exclaimed.",
    "I might want to use 'single' quotes, too.": "I might want to use ‘single’ quotes, too.",
    "\"That's why we support quotes and apostrophes.\"": "“That’s why we support quotes and apostrophes.”",
    "": "",
    "I like -- make that _love_ -- the em dash.": "I like — make that _love_ — the em dash.",
    "....": "…",
    "...": "…",
    "And the names of the famous dead as well.... Everything fades so quickly,": "And the names of the famous dead as well… Everything fades so quickly,",
  ]

  // TODO: Find out why this crashes
  func BROKEN_testExamples() {
    for testCase in examples {
      XCTAssertEqual(testCase.key.withTypographySubstitutions, testCase.value)
    }
  }

  func testAttributedString() {
    for testCase in examples {
      let attributedString = NSAttributedString(string: testCase.key)
      let afterSubtitution = attributedString.withTypographySubstitutions
      XCTAssertEqual(attributedString.string, testCase.key)
      XCTAssertEqual(afterSubtitution.string, testCase.value)
    }
  }
}
