// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import MaterialComponents.MDCTypographyScheme
import MiniMarkdown
import TextBundleKit
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
      vocabularyAssociation.english,
      promptWithSpanish ? "spanish" : "english",
    ].joined(separator: ":")
  }

  func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView {
    return VocabularyAssociationCardView(card: self, parseableDocument: parseableDocument, stylesheet: stylesheet)
  }

  func context(document: ParseableDocument, stylesheet: Stylesheet) -> NSAttributedString {
    let font = stylesheet.typographyScheme.overline
    let contextString = promptWithSpanish
      ? "How do you say this in English?"
      : "How do you say this in Spanish?"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  func prompt(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> NSAttributedString {
    let phrase = promptWithSpanish
      ? vocabularyAssociation.spanish
      : vocabularyAssociation.english
    let blocks = parseableDocument.parsingRules.parse(phrase)
    let renderer = MarkdownAttributedStringRenderer.promptRenderer(
      document: parseableDocument.document,
      stylesheet: stylesheet
    )
    return blocks.map({ renderer.render(node: $0) }).joined()
  }

  func answer(document: ParseableDocument, stylesheet: Stylesheet) -> NSAttributedString {
    let phrase = promptWithSpanish
      ? vocabularyAssociation.english
      : vocabularyAssociation.spanish
    let blocks = document.parsingRules.parse(phrase)
    let renderer = MarkdownAttributedStringRenderer.answerRenderer(
      document: document.document,
      stylesheet: stylesheet
    )
    return blocks.map({ renderer.render(node: $0) }).joined()
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
    var renderer = MarkdownAttributedStringRenderer()
    renderer.renderFunctions[.text] = { (node) in
      return NSAttributedString(
        string: String(node.slice.substring),
        attributes: stylesheet.attributes(style: style)
      )
    }
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
    guard let document = document as? TextBundleDocument else { return renderer }
    renderer.renderFunctions[.image] = { (node) in
      let results = NSMutableAttributedString()
      let imageNode = node as! MiniMarkdown.Image
      if let image = document.image(for: node) {
        let attachment = NSTextAttachment()
        attachment.image = image
        let aspectRatio = image.size.width / image.size.height
        attachment.bounds = CGRect(x: 0, y: 0, width: 100.0 * aspectRatio, height: 100.0)
        results.append(NSAttributedString(attachment: attachment))
      }
      if !imageNode.text.isEmpty {
        results.append(
          NSAttributedString(
            string: "\n" + String(imageNode.text),
            attributes: stylesheet.attributes(style: captionStyle)
          )
        )
      }
      return results
    }
    return renderer
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
