// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
@testable import FlashcardKit
import XCTest

final class LanguageDeckTests: LanguageDeckBase {

  func testStudySessionHasCloze() {
    let didGetValue = expectation(description: "did get value")
    let stylesheet = Stylesheet()
    let endpoint = languageDeck.studySessionSignal.subscribeValues { (studySession) in
      var studySession = studySession
      var didGetCloze = false
      while let card = studySession.currentCard {
        if let cloze = card.card as? ClozeCard {
          didGetCloze = true
          let node = LanguageDeck.parsingRules.parse(cloze.markdown)[0]
          let cardFrontRenderer = MarkdownAttributedStringRenderer.cardFront(
            stylesheet: stylesheet,
            hideClozeAt: cloze.clozeIndex
          )
          let cardBackRenderer = MarkdownAttributedStringRenderer.cardBackRenderer(
            stylesheet: stylesheet,
            revealingClozeAt: cloze.clozeIndex
          )
          XCTAssertEqual(cardFrontRenderer.render(node: node).string, "La nieve to be blanca.\n")
          XCTAssertEqual(cardBackRenderer.render(node: node).string, "La nieve es blanca.\n")
        }
        studySession.recordAnswer(correct: true)
      }
      XCTAssert(didGetCloze)
      didGetValue.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    endpoint.cancel()
  }
}
