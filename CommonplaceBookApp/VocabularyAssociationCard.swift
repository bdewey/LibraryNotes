// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import MaterialComponents.MDCTypographyScheme
import MiniMarkdown
import TextBundleKit
import UIKit

/// A specific card for a vocabulary association.
// TODO: Don't hard-code the fonts in here.
struct VocabularyAssociationCard: Challenge {
  private let vocabularyAssociation: VocabularyAssociation
  private let promptWithSpanish: Bool
  let challengeIdentifier: ChallengeIdentifier

  init(vocabularyAssociation: VocabularyAssociation, promptWithSpanish: Bool, templateIndex: Int) {
    self.vocabularyAssociation = vocabularyAssociation
    self.promptWithSpanish = promptWithSpanish
    self.challengeIdentifier = ChallengeIdentifier(
      templateDigest: vocabularyAssociation.templateIdentifier,
      index: templateIndex
    )
  }

  var identifier: String {
    return [
      vocabularyAssociation.spanish,
      vocabularyAssociation.english,
      promptWithSpanish ? "spanish" : "english",
    ].joined(separator: ":")
  }

  func challengeView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> ChallengeView {
    return VocabularyAssociationCardView(
      card: self,
      document: document,
      properties: properties,
      stylesheet: stylesheet
    )
  }

  func context(stylesheet: Stylesheet) -> NSAttributedString {
    let font = stylesheet.typographyScheme.overline
    let contextString = promptWithSpanish
      ? "How do you say this in English?"
      : "How do you say this in Spanish?"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  func prompt(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> NSAttributedString {
    let phrase = promptWithSpanish
      ? vocabularyAssociation.spanish
      : vocabularyAssociation.english
    let blocks = properties.parsingRules.parse(phrase)
    let renderer = MarkdownAttributedStringRenderer.promptRenderer(
      document: document,
      stylesheet: stylesheet
    )
    return blocks.map { renderer.render(node: $0) }.joined()
  }

  func answer(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> NSAttributedString {
    let phrase = promptWithSpanish
      ? vocabularyAssociation.english
      : vocabularyAssociation.spanish
    let blocks = properties.parsingRules.parse(phrase)
    let renderer = MarkdownAttributedStringRenderer.answerRenderer(
      document: document,
      stylesheet: stylesheet
    )
    return blocks.map { renderer.render(node: $0) }.joined()
  }

  var pronunciation: String {
    return vocabularyAssociation.spanish
  }
}

// TODO: Move this to CommonplaceBook

extension MarkdownAttributedStringRenderer {
  static func textRenderer(
    stylesheet: Stylesheet,
    style: Stylesheet.Style
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer.textOnly
    renderer.defaultAttributes = stylesheet.attributes(style: style)
    return renderer
  }

  /// Retuerns a rendereer that knows how to render images IF `document` is a TextBundleDocument.
  /// Otherwise, this will be a textRenderer.
  static func textAndImageRenderer(
    document: UIDocument,
    stylesheet: Stylesheet,
    textStyle: Stylesheet.Style,
    captionStyle: Stylesheet.Style
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer.textRenderer(
      stylesheet: stylesheet,
      style: textStyle
    )
    return renderer
//    guard let document = document as? TextBundleDocument else { return renderer }
//    renderer.renderFunctions[.image] = { node, _ in
//      let results = NSMutableAttributedString()
//      let imageNode = node as! MiniMarkdown.Image // swiftlint:disable:this force_cast
//      if let image = document.image(for: node) {
//        let attachment = NSTextAttachment()
//        attachment.image = image
//        let aspectRatio = image.size.width / image.size.height
//        attachment.bounds = CGRect(x: 0, y: 0, width: 100.0 * aspectRatio, height: 100.0)
//        results.append(NSAttributedString(attachment: attachment))
//      }
//      if !imageNode.text.isEmpty {
//        results.append(
//          NSAttributedString(
//            string: "\n" + String(imageNode.text),
//            attributes: stylesheet.attributes(style: captionStyle)
//          )
//        )
//      }
//      return results
//    }
//    return renderer
  }

  static func promptRenderer(
    document: UIDocument,
    stylesheet: Stylesheet
  ) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.textAndImageRenderer(
      document: document,
      stylesheet: stylesheet,
      textStyle: .headline6,
      captionStyle: .headline6
    )
  }

  static func answerRenderer(
    document: UIDocument,
    stylesheet: Stylesheet
  ) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.textAndImageRenderer(
      document: document,
      stylesheet: stylesheet,
      textStyle: .body2,
      captionStyle: .body2
    )
  }
}
