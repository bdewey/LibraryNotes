// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
@testable import FlashcardKit
import MiniMarkdown
import XCTest

final class ClozeTests: XCTestCase {
  private let parsingRules: MiniMarkdown.ParsingRules = {
    var parsingRules = MiniMarkdown.ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
    return parsingRules
  }()

  func testFindClozeInText() {
    let example = """
# Mastering the verb "to be"

In Spanish, there are two verbs "to be": *ser* and *estar*.

1. *Ser* is used to identify a person, an animal, a concept, a thing, or any noun.
2. *Estar* is used to show location.
3. *Ser*, with an adjective, describes the "norm" of a thing.
   - La nieve ?[to be](es) blanca.
4. *Estar* with an adjective shows a "change" or "condition."
"""
    let blocks = parsingRules.parse(example)
    XCTAssertEqual(blocks[4].type, .list)
    let clozeNodes = blocks.map({ $0.findNodes(where: { $0.type == .cloze }) }).joined()
    XCTAssertEqual(clozeNodes.count, 1)
    if let cloze = clozeNodes.first as? Cloze {
      XCTAssertEqual(cloze.slice.substring, "?[to be](es)")
      XCTAssertEqual(cloze.hiddenText, "es")
      XCTAssertEqual(cloze.hint, "to be")
    }
  }

  func testMultipleClozesInAnItem() {
    let example = """
* Yo ?[to be](soy) de España. ¿De dónde ?[to be](es) ustedes?
"""
    let blocks = parsingRules.parse(example)
    XCTAssertEqual(blocks.count, 1)
    let clozeCards = ClozeTemplate.extract(from: blocks).cards as! [ClozeCard]
    XCTAssertEqual(clozeCards.count, 2)
    XCTAssertEqual(
      clozeCards[1].markdown,
      "Yo ?[to be](soy) de España. ¿De dónde ?[to be](es) ustedes?"
    )
    XCTAssertEqual(clozeCards[1].clozeIndex, 1)
    let stylesheet = Stylesheet()
    let cardFrontRenderer = MarkdownAttributedStringRenderer.cardFront(
      stylesheet: stylesheet,
      hideClozeAt: clozeCards[0].clozeIndex
    )
    let node = parsingRules.parse(clozeCards[0].markdown)[0]
    XCTAssertEqual(
      cardFrontRenderer.render(node: node).string,
      "Yo to be de España. ¿De dónde es ustedes?"
    )
    XCTAssertEqual(
      clozeCards[1].cardFrontRenderer(stylesheet: stylesheet).render(node: node).string,
      "Yo soy de España. ¿De dónde to be ustedes?"
    )
  }
}
