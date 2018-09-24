// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import UIKit

struct VocabularyAssociationSpellingCard: Card {
  init(vocabularyAssociation: VocabularyAssociation) {
    self.vocabularyAssociation = vocabularyAssociation
  }

  private let vocabularyAssociation: VocabularyAssociation

  var identifier: String {
    return [
      vocabularyAssociation.spanish,
      vocabularyAssociation.english.identifier,
      "spelling",
    ].joined(separator: ":")
  }

  func cardView(with stylesheet: Stylesheet) -> CardView {
    return VocabularyAssociationSpellingCardView(card: self)
  }

  var spanish: String {
    return vocabularyAssociation.spanish
  }

  var image: UIImage? {
    return vocabularyAssociation.english.image
  }
}
