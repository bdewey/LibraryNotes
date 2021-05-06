// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

@testable import GrailDiary
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
  func testExamples() {
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
