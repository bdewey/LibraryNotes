// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CwlSignal
import Foundation
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

/// This class is the model layer for a single "language deck" (flashcards & study statistics).
/// It is backed by a single UIDocument.
public final class LanguageDeck {

  /// Initializer.
  ///
  /// - parameter document: The document that stores all of the models
  ///             (vocabulary cards, stats, ...)
  public init(document: TextBundleDocument) {

    // EWWW -- touching global state.
    // TODO: Remove this.

    var parsingRules = MiniMarkdown.ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)

    self.document = document
    self.miniMarkdown = MiniMarkdownSignal(textStorage: document.text, parsingRules: parsingRules)

    let vocabularyAssociationsSignal = miniMarkdown.signal
      .map { (blocks) -> [VocabularyAssociation] in
        return VocabularyAssociation.makeAssociations(from: blocks, document: document).0
      }
    let clozeCardSignal = miniMarkdown.signal.map { ClozeCard.makeCards(from: $0) }
    let combinedCards = vocabularyAssociationsSignal
      .combineLatest(clozeCardSignal) { (vocabularyAssociations, closeCards) -> [Card] in
        return Array([vocabularyAssociations.cards, closeCards].joined())
      }
    self.studySessionSignal = document.documentStudyMetadata.signal
      .combineLatest(combinedCards, { (documentValue, cards) -> StudySession in
        return documentValue.value.studySession(from: cards, limit: 500)
      })
  }

  /// The document that stores all of the models.
  public let document: TextBundleDocument
  public let miniMarkdown: MiniMarkdownSignal
  public let studySessionSignal: Signal<StudySession>

  public func populateEmptyDocument() {
    if document.text.currentResult.value.isEmpty {
      document.text.setValue(initialText)
    }
  }

  /// Opens a LanguageDeck document.
  public static func open(
    at pathComponent: String,
    completion: @escaping (Result<LanguageDeck>) -> Void
  ) {
    // TODO: useCloud should be a user setting.
    let factory = TextBundleDocumentFactory(useCloud: true)
    CommonplaceBook.openDocument(at: pathComponent, using: factory) { (documentResult) in
      let deckResult = documentResult.flatMap({ (document) -> LanguageDeck in
        let deck = LanguageDeck(document: document)
        deck.populateEmptyDocument()
        return deck
      })
      completion(deckResult)
    }
  }
}

private let initialText = """
# Summer Spanish Review

These are the words Alex practiced during the summer of 2018:

| Spanish | Engish |
| --------| ------ |
| tenedor | fork   |
| hombre  | man    |
| mujer   | woman  |
| niño    | boy    |
| niña    | girl   |

# Mastering the verb "to be"

In Spanish, there are two verbs "to be": *ser* and *estar*.

1. *Ser* is used to identify a person, an animal, a concept, a thing, or any noun.
2. *Estar* is used to show location.
3. *Ser*, with an adjective, describes the "norm" of a thing.
   - La nieve ?[to be](es) blanca.
4. *Estar* with an adjective shows a "change" or "condition."

"""