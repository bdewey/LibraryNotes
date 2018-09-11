// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class NormalizedCollectionTests: XCTestCase {

  typealias StringChange = RangeReplaceableChange<Substring>

  func testNoSubstitutions() {
    let input = "This is a string."
    let expectedOutput = input
    validateNormalization(
      input: input,
      expectedOutput: expectedOutput,
      transformation: replaceTabsWithSpaces
    )
  }

  func testSingleSubstitution() {
    let input = "Text\twith tab"
    let expectedOutput = "Text    with tab"
    validateNormalization(
      input: input,
      expectedOutput: expectedOutput,
      transformation: replaceTabsWithSpaces
    )
  }

  func testMultipleExpandingSubstitutions() {
    let input = "1\t2\t3"
    let expectedOutput = "1    2    3"
    validateNormalization(
      input: input,
      expectedOutput: expectedOutput,
      transformation: replaceTabsWithSpaces
    )
  }

  func testMultipleShrinkingSubstitutions() {
    let input = "1    2    3"
    let expectedOutput = "1\t2\t3"
    validateNormalization(
      input: input,
      expectedOutput: expectedOutput,
      transformation: replaceSpacesWithTabs
    )
  }

  func testSimpleMutation() {
    let input = "1\t2\t3"
    var normalized = NormalizedCollection(
      originalCollection: input,
      normalizingChanges: replaceTabsWithSpaces(input: input)
    )
    normalized[normalized.startIndex] = "x"
    XCTAssertEqual(normalized.normalizedCollection, "x    2    3")
    XCTAssertEqual(normalized.originalCollection, "x\t2\t3")
  }

  func testInsertMutation() {
    let input = "1\t2\t3"
    var normalized = NormalizedCollection(
      originalCollection: input,
      normalizingChanges: replaceTabsWithSpaces(input: input)
    )
    XCTAssertEqual(input, normalized.originalCollection)
    XCTAssertEqual("1    2    3", normalized.normalizedCollection)
    normalized.insert("!", at: normalized.startIndex)
    XCTAssertEqual(normalized.normalizedCollection, "!1    2    3")
    XCTAssertEqual(normalized.originalCollection, "!1\t2\t3")
  }

  func testReplaceTextInMiddle() {
    let input = "alpha\tbeta\tgamma\n"
    var normalized = NormalizedCollection(
      originalCollection: input,
      normalizingChanges: replaceTabsWithSpaces(input: input)
    )
    guard let rangeToReplace = normalized.normalizedCollection.range(of: "beta") else {
      XCTFail("where is my range?")
      return
    }
    normalized.replaceSubrange(rangeToReplace, with: "BETA")
    XCTAssertEqual(normalized.normalizedCollection, "alpha    BETA    gamma\n")
    XCTAssertEqual(normalized.originalCollection, "alpha\tBETA\tgamma\n")
  }

  func testShrinkTextInMiddle() {
    let input = "alpha\tbeta\tgamma\n"
    var normalized = NormalizedCollection(
      originalCollection: input,
      normalizingChanges: replaceTabsWithSpaces(input: input)
    )
    guard let rangeToReplace = normalized.normalizedCollection.range(of: "beta") else {
      XCTFail("could not find range?!")
      return
    }
    normalized.replaceSubrange(rangeToReplace, with: "ß")
    XCTAssertEqual(normalized.normalizedCollection, "alpha    ß    gamma\n")
    XCTAssertEqual(normalized.originalCollection, "alpha\tß\tgamma\n")
  }

  func validateNormalization(
    input: String,
    expectedOutput: String,
    transformation: (String) -> [StringChange],
    testCaseName: String = #function
  ) {
    let normalized = NormalizedCollection(
      originalCollection: input,
      normalizingChanges: transformation(input)
    )
    XCTAssertEqual(input, normalized.originalCollection, testCaseName)
    XCTAssertEqual(expectedOutput, normalized.normalizedCollection, testCaseName)
  }

  func replaceTabsWithSpaces(input: String) -> [StringChange] {
    var results: [StringChange] = []
    for (index, character) in zip(input.indices, input) where character == "\t" {
      let change = StringChange(
        range: NSRange(index...index, in: input),
        newElements: "    "
      )
      results.append(change)
    }
    return results
  }

  func replaceSpacesWithTabs(input: String) -> [StringChange] {
    var results: [StringChange] = []
    var searchSubsequence = input[input.startIndex...]
    while let spaceRange = searchSubsequence.range(of: "    ") {
      let location = input.distance(from: input.startIndex, to: spaceRange.lowerBound)
      let change = StringChange(range: NSRange(location: location, length: 4), newElements: "\t")
      results.append(change)
      searchSubsequence = input[spaceRange.upperBound...]
    }
    return results
  }
}
