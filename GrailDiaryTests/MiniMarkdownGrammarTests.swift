// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

@testable import CommonplaceBookApp
import Foundation
import XCTest

final class ParsingRuleTests: XCTestCase {
  func testDotMatchesEverything() {
    XCTAssertNil(DotRule().possibleOpeningCharacters)
  }

  func testTraceDotMatchesEverything() {
    XCTAssertNil(DotRule().trace().possibleOpeningCharacters)
  }

  func testNotOptionalSequence() {
    let chars = InOrder(
      Literal("A"),
      Literal("B")
    ).possibleOpeningCharacters
    XCTAssertEqual(chars, CharacterSet(charactersIn: "A"))
  }

  func testOptionalSequence() {
    let chars = InOrder(
      Literal("A").zeroOrOne(),
      Literal("B")
    ).possibleOpeningCharacters
    XCTAssertEqual(chars, CharacterSet(charactersIn: "AB"))
  }

  func testChoice() {
    let chars = Choice(
      Literal("A"),
      Literal("B")
    ).possibleOpeningCharacters
    XCTAssertEqual(chars, CharacterSet(charactersIn: "AB"))
  }

  func testInOrderFiltering() {
    let chars = InOrder(
      Literal("!").assert(),
      DotRule()
    ).possibleOpeningCharacters
    let expected = CharacterSet(charactersIn: "!")
    assertSameAnswers(chars, expected)
  }

  func testTraceModifications() {
    let grammar = MiniMarkdownGrammar()
    let unmodified = grammar.paragraph.possibleOpeningCharacters
    let trace = grammar.paragraph.trace().possibleOpeningCharacters
    assertSameAnswers(unmodified, trace)
  }

  func testParagraphMembership() {
    let grammar = MiniMarkdownGrammar()
    XCTAssertTrue(grammar.paragraphTermination.possibleOpeningCharacters!.contains("\n"))
    XCTAssertTrue(grammar.textStyles.possibleOpeningCharacters!.contains("*"))
    XCTAssertTrue(grammar.styledText.possibleOpeningCharacters?.contains("*") ?? true)
    XCTAssertTrue(grammar.paragraph.possibleOpeningCharacters?.contains("*") ?? true)
  }

  let testString = "#abc123!?xABC\n \t."

  func assertSameAnswers(_ set1: CharacterSet?, _ set2: CharacterSet?, file: StaticString = #file, line: UInt = #line) {
    let matched1 = set1.matchedCharacters(from: testString)
    let matched2 = set2.matchedCharacters(from: testString)

    if matched1 != matched2 {
      let difference = matched1.symmetricDifference(matched2)
      XCTFail("Got different answers with the following characters: \(difference)", file: file, line: line)
    }
  }
}

extension Optional where Wrapped == CharacterSet {
  func matchedCharacters(from str: String) -> Set<UnicodeScalar> {
    switch self {
    case .none:
      return str.scalars(matching: { _ in true })
    case .some(let set):
      return str.scalars(matching: { set.contains($0) })
    }
  }
}

extension String {
  func scalars(matching predicate: (UnicodeScalar) -> Bool) -> Set<UnicodeScalar> {
    var results = Set<UnicodeScalar>()
    for scalar in unicodeScalars where predicate(scalar) {
      results.insert(scalar)
    }
    return results
  }
}
