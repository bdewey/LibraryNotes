// Copyright © 2017-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
import XCTest

private let expectedMarkdown = """
| Spanish | Engish |
| ------- | ------ |
| tenedor | fork   |
| hombre  | man    |
| mujer   | woman  |
| niño    | boy    |
| niña    | girl   |

"""

private let spellingMarkdown = """
| Spanish           | Engish |
| ----------------- | ------ |
| tenedor #spelling | fork   |
| hombre            | man    |

"""

private let sampleAssociations = [
  VocabularyAssociation(spanish: "tenedor", english: "fork"),
  VocabularyAssociation(spanish: "hombre", english: "man"),
  VocabularyAssociation(spanish: "mujer", english: "woman"),
  VocabularyAssociation(spanish: "niño", english: "boy"),
  VocabularyAssociation(spanish: "niña", english: "girl"),
]

final class VocabularyAssocationTests: XCTestCase {
  func testMakeMarkdown() {
    let markdown = sampleAssociations.makeTable()
    XCTAssertEqual(markdown, expectedMarkdown)
  }

  func testLoadMarkdown() {
    let cards = VocabularyAssociation.makeAssociations(
      from: expectedMarkdown
    ).0
    XCTAssertEqual(cards, sampleAssociations)
  }

  func testMakeCards() {
    let assocations = sampleAssociations
    let cards = assocations.cards
    XCTAssertEqual(cards.count, assocations.count * 2)
  }

  func testLoadSpelling() {
    let cards = VocabularyAssociation.makeAssociations(
      from: spellingMarkdown
    ).0
    let expectedCards = [
      VocabularyAssociation(spanish: "tenedor", english: "fork", testSpelling: true),
      VocabularyAssociation(spanish: "hombre", english: "man"),
    ]
    XCTAssertEqual(cards, expectedCards)
  }

  func testSaveSpelling() {
    let associations = [
      VocabularyAssociation(spanish: "tenedor", english: "fork", testSpelling: true),
      VocabularyAssociation(spanish: "hombre", english: "man"),
    ]
    XCTAssertEqual(associations.makeTable(), spellingMarkdown)
  }

  func testParseImage() {
    let markdown = """
    | Spanish           | Engish |
    | ----------------- | ------ |
    | tenedor #spelling | fork   |
    | hombre            | ![man](assets/hombre.png) |
    """
    let cards = VocabularyAssociation.makeAssociations(
      from: markdown
    ).0
    let expectedCards = [
      VocabularyAssociation(spanish: "tenedor", english: "fork", testSpelling: true),
      VocabularyAssociation(spanish: "hombre", english: "![man](assets/hombre.png)"),
    ]
    XCTAssertEqual(cards, expectedCards)
  }
}
