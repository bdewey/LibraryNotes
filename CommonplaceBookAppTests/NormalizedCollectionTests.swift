// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest
import CommonplaceBookApp

final class NormalizedCollectionTests: XCTestCase {
  
  typealias StringChange = RangeReplaceableChange<String.Index, Substring>

  func testNoSubstitutions() {
    let input = "This is a string."
    let expectedOutput = input
    validateNormalization(input: input, expectedOutput: expectedOutput, transformation: replaceTabsWithSpaces)
  }
  
  func testSingleSubstitution() {
    let input = "Text\twith tab"
    let expectedOutput = "Text    with tab"
    validateNormalization(input: input, expectedOutput: expectedOutput, transformation: replaceTabsWithSpaces)
  }
  
  func testMultipleExpandingSubstitutions() {
    let input = "1\t2\t3"
    let expectedOutput = "1    2    3"
    validateNormalization(input: input, expectedOutput: expectedOutput, transformation: replaceTabsWithSpaces)
  }
  
  func testMultipleShrinkingSubstitutions() {
    let input = "1    2    3"
    let expectedOutput = "1\t2\t3"
    validateNormalization(input: input, expectedOutput: expectedOutput, transformation: replaceSpacesWithTabs)
  }
  
  func validateNormalization(
    input: String,
    expectedOutput: String,
    transformation: (String) -> [StringChange],
    testCaseName: String = #function
  ) {
    let normalized = NormalizedCollection(originalCollection: input, normalizingChanges: transformation(input))
    XCTAssertEqual(input, normalized.originalCollection, testCaseName)
    XCTAssertEqual(expectedOutput, normalized.normalizedCollection, testCaseName)
  }
  
  func replaceTabsWithSpaces(input: String) -> [StringChange] {
    var results: [StringChange] = []
    for (index, character) in zip(input.indices, input) {
      if character == "\t" {
        let nextIndex = input.index(after: index)
        results.append(StringChange(range: index ..< nextIndex, newElements: "    "))
      }
    }
    return results
  }
  
  func replaceSpacesWithTabs(input: String) -> [StringChange] {
    var results: [StringChange] = []
    var searchSubsequence = input[input.startIndex...]
    while let spaceRange = searchSubsequence.range(of: "    ") {
      results.append(StringChange(range: spaceRange, newElements: "\t"))
      searchSubsequence = input[spaceRange.upperBound...]
    }
    return results
  }
}
