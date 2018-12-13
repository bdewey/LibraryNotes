// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import TextBundleKit
import UIKit

struct VocabularyAssociationSpellingCard: Card {
  init(vocabularyAssociation: VocabularyAssociation) {
    self.vocabularyAssociation = vocabularyAssociation
  }

  private let vocabularyAssociation: VocabularyAssociation

  var identifier: String {
    return [
      vocabularyAssociation.spanish,
      vocabularyAssociation.english,
      "spelling",
    ].joined(separator: ":")
  }

  func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView {
    return VocabularyAssociationSpellingCardView(
      card: self,
      parseableDocument: parseableDocument,
      stylesheet: stylesheet
    )
  }

  var spanish: String {
    return vocabularyAssociation.spanish
  }

  func image(parseableDocument: ParseableDocument) -> UIImage? {
    guard let document = parseableDocument.document as? TextBundleDocument else { return nil }
    let blocks = parseableDocument.parsingRules.parse(vocabularyAssociation.english)
    return blocks.map { $0.findNodes(where: { $0.type == .image }) }
      .joined()
      .compactMap { document.image(for: $0) }
      .first
  }
}
