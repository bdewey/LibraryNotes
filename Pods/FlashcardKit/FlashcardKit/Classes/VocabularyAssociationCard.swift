// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import UIKit

/// A specific card for a vocabulary association.
/// TODO: Don't hard-code the fonts in here.
struct VocabularyAssociationCard: Card {

  private let vocabularyAssociation: VocabularyAssociation
  private let promptWithSpanish: Bool

  init(vocabularyAssociation: VocabularyAssociation, promptWithSpanish: Bool) {
    self.vocabularyAssociation = vocabularyAssociation
    self.promptWithSpanish = promptWithSpanish
  }

  var identifier: String {
    return [
      vocabularyAssociation.spanish,
      vocabularyAssociation.english.identifier,
      promptWithSpanish ? "spanish" : "english",
    ].joined(separator: ":")
  }

  func cardView(with stylesheet: Stylesheet) -> CardView {
    return VocabularyAssociationCardView(card: self)
  }

  var context: NSAttributedString {
    let font = Stylesheet.hablaEspanol.typographyScheme.overline
    let contextString = promptWithSpanish
      ? "How do you say this in English?"
      : "How do you say this in Spanish?"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  var prompt: NSAttributedString {
    let font = Stylesheet.hablaEspanol.typographyScheme.headline6
    let phrase = promptWithSpanish
      ? NSAttributedString(string: vocabularyAssociation.spanish, attributes: [.font: font])
      : vocabularyAssociation.english.attributedString(with: font)
    return phrase
  }

  var answer: NSAttributedString {
    let font = Stylesheet.hablaEspanol.typographyScheme.body2
    let phrase = promptWithSpanish
      ? vocabularyAssociation.english.attributedString(with: font)
      : NSAttributedString(string: vocabularyAssociation.spanish, attributes: [.font: font])
    return phrase
  }

  var pronunciation: String {
    return vocabularyAssociation.spanish
  }
}
