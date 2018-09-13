//
//  LineRangeSequenceTests.swift
//  ScratchpadTests
//
//  Created by Brian Dewey on 6/28/18.
//  Copyright © 2018 Brian's Brain. All rights reserved.
//

import XCTest
@testable import MiniMarkdown

extension Sequence where Iterator.Element == StringSlice {
  
  fileprivate var stringArray: [String] {
    return self.map { return String($0.substring) }
  }
}

final class LineSequenceTests: XCTestCase {

  func testEnumerateWithNoLineBreaks() {
    XCTAssertEqual(LineSequence("abc").stringArray, ["abc"])
  }
  
  func testEnumerationWithSingleTerminatingCharacter() {
    XCTAssertEqual(LineSequence("abc\n").stringArray, ["abc\n"])
  }
  
  func testMultipleLinesNoFinalTermination() {
    XCTAssertEqual(LineSequence("abc\ndef\nghi").stringArray, ["abc\n", "def\n", "ghi"])
  }
  
  func testMultipleLinesWithFinalTermination() {
    XCTAssertEqual(LineSequence("abc\ndef\nghi\n").stringArray, ["abc\n", "def\n", "ghi\n"])
  }
  
  func testBlankLines() {
    XCTAssertEqual(LineSequence("\n\n").stringArray, ["\n", "\n"])
  }
}
