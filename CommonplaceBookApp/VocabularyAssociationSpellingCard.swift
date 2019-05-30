// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import TextBundleKit
import UIKit

struct VocabularyAssociationSpellingCard: Challenge {
  init(vocabularyAssociation: VocabularyAssociation, templateIndex: Int) {
    self.vocabularyAssociation = vocabularyAssociation
    self.challengeIdentifier = ChallengeIdentifier(
      templateDigest: vocabularyAssociation.templateIdentifier,
      index: templateIndex
    )
  }

  private let vocabularyAssociation: VocabularyAssociation
  var challengeIdentifier: ChallengeIdentifier

  var identifier: String {
    return [
      vocabularyAssociation.spanish,
      vocabularyAssociation.english,
      "spelling",
    ].joined(separator: ":")
  }

  func challengeView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> ChallengeView {
    return VocabularyAssociationSpellingCardView(
      card: self,
      document: document,
      parseableDocument: properties,
      stylesheet: stylesheet
    )
  }

  var spanish: String {
    return vocabularyAssociation.spanish
  }

  func image(document: UIDocument, parseableDocument: CardDocumentProperties) -> UIImage? {
    guard let document = document as? TextBundleDocument else { return nil }
    let blocks = parseableDocument.parsingRules.parse(vocabularyAssociation.english)
    return blocks.map { $0.findNodes(where: { $0.type == .image }) }
      .joined()
      .compactMap { document.image(for: $0) }
      .first
  }
}
