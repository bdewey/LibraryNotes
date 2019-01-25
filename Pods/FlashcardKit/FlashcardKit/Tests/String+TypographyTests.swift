// Copyright © 2018-present Brian's Brain. All rights reserved.

@testable import FlashcardKit
import XCTest

final class String_TypographyTests: XCTestCase {
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

  func testExamples() {
    for testCase in examples {
      XCTAssertEqual(testCase.key.withTypographySubstitutions, testCase.value)
    }
  }
}
