// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Library_Notes
import TextMarkupKit
import XCTest

final class SummaryTests: XCTestCase {
  @MainActor func testSummary() throws {
    let example = """
    # _Book_, Author (Year)

    tl;dr: I loved it. **Everyone** should read it.

    Detailed notes here.
    """

    try parseText(
      example,
      expectedStructure: "(document (header delimiter tab (emphasis delimiter text delimiter) text) blank_line (summary summary_delimiter (summary_body text (strong_emphasis delimiter text delimiter) text) summary_body) blank_line (paragraph text))"
    )
  }

  @MainActor func testCaseInsensitiveSummary() throws {
    let example = """
    # _Book_, Author (Year)

    Tl;dr: I loved it. **Everyone** should read it.

    Detailed notes here.
    """

    try parseText(
      example,
      expectedStructure: "(document (header delimiter tab (emphasis delimiter text delimiter) text) blank_line (summary summary_delimiter (summary_body text (strong_emphasis delimiter text delimiter) text) summary_body) blank_line (paragraph text))"
    )
  }

  @MainActor private func parseText(_ text: String, expectedStructure: String) throws {
    let parsedString = ParsedString(text, grammar: GrailDiaryGrammar.shared)
    do {
      try parsedString.parsedResultsThatMatch(expectedStructure)
    } catch ParsedString.ValidationError.validationError(let message) {
      print(message)
      throw ParsedString.ValidationError.validationError(message)
    }
  }
}
