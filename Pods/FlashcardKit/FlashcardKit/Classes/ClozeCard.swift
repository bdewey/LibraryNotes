// Copyright © 2018-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import CommonplaceBook
import Foundation
import MiniMarkdown
import TextBundleKit

/// A Card for remembering a sentence with a word/phrase removed and optionally replaced with
/// a hint. The removed word/phrase is a "cloze".
///
/// See https://en.wikipedia.org/wiki/Cloze_test
public struct ClozeCard: Codable {
  /// Designated initializer.
  ///
  /// - parameter markdown: The markdown content that contains at least one cloze.
  /// - parameter closeIndex: The index of the cloze in `markdown` to remove when testing.
  public init(markdown: String, clozeIndex: Int) {
    self.markdown = markdown
    self.clozeIndex = clozeIndex
  }

  /// The markdown content that contains at least one cloze.
  public let markdown: String

  /// The index of the cloze in `markdown` to remove when testing.
  public let clozeIndex: Int

  /// Creates a renderer that will render `markdown` with the cloze at `clozeIndex` removed,
  /// replaced with a hint if present, and highlighted.
  public func cardFrontRenderer(stylesheet: Stylesheet) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.cardFront(
      stylesheet: stylesheet,
      hideClozeAt: clozeIndex
    )
  }
}

extension ClozeCard: Card {
  public var identifier: String {
    let suffix = clozeIndex > 0 ? "::\(clozeIndex)" : ""
    return markdown + suffix
  }

  public func cardView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> CardView {
    let cardView = TwoSidedCardView(frame: .zero)
    let nodes = properties.parsingRules.parse(markdown)
    assert(nodes.count == 1)
    let node = nodes[0]
    cardView.context = context(stylesheet: stylesheet)
    let (front, chapterAndVerse) = cardFront(node: node, stylesheet: stylesheet)
      .decomposedChapterAndVerseAnnotation
    cardView.front = front
    let back = NSMutableAttributedString()
    back.append(cardBack(node: node, stylesheet: stylesheet).removingChapterAndVerseAnnotation())
    if !properties.attributionMarkdown.isEmpty {
      back.append(NSAttributedString(string: "\n"))
      let attributionRenderer = RenderedMarkdown(
        stylesheet: stylesheet,
        style: .caption,
        parsingRules: properties.parsingRules
      )
      attributionRenderer.markdown = "—" + properties.attributionMarkdown + " " + chapterAndVerse
      back.append(attributionRenderer.attributedString)
    }
    cardView.back = back
    cardView.stylesheet = stylesheet
    return cardView
  }

  func utterance(node: Node, stylesheet: Stylesheet) -> AVSpeechUtterance {
    let phrase = clozeRenderer.render(node: node).string
    let utterance = AVSpeechUtterance(string: phrase)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
    return utterance
  }

  func context(stylesheet: Stylesheet) -> NSAttributedString {
    let font = stylesheet.typographyScheme.overline
    let contextString = "Fill in the blank"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  func cardFront(node: Node, stylesheet: Stylesheet) -> NSAttributedString {
    return cardFrontRenderer(stylesheet: stylesheet).render(node: node)
  }

  func cardBack(node: Node, stylesheet: Stylesheet) -> NSAttributedString {
    return MarkdownAttributedStringRenderer
      .cardBackRenderer(stylesheet: stylesheet, revealingClozeAt: clozeIndex)
      .render(node: node)
  }
}

extension MarkdownAttributedStringRenderer {
  /// Builds a renderer that will replace the cloze at clozeIndex with its hint and
  /// highlight the cloze.
  static func cardFront(
    stylesheet: Stylesheet,
    hideClozeAt index: Int
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(stylesheet: stylesheet, style: .body2)
    var renderedCloze = 0
    renderer.renderFunctions[.cloze] = { node, _ in
      guard let cloze = node as? Cloze else { return NSAttributedString() }
      let shouldHide = renderedCloze == index
      renderedCloze += 1
      if shouldHide {
        if cloze.hint.strippingLeadingAndTrailingWhitespace.isEmpty {
          // There is no real hint. So instead put the hidden text but render it using the
          // background color. That way it takes up the correct amount of space in the string,
          // but is still invisible.
          var attributes = stylesheet.clozeAttributes
          attributes[.foregroundColor] = attributes[.backgroundColor]
          return NSAttributedString(string: String(cloze.hiddenText), attributes: attributes)
        } else {
          return NSAttributedString(
            string: String(cloze.hint),
            attributes: stylesheet.clozeAttributes
          )
        }
      } else {
        return NSAttributedString(
          string: String(cloze.hiddenText),
          attributes: stylesheet.textAttributes
        )
      }
    }
    return renderer
  }

  /// Builds a renderer that will show and highlight the cloze at clozeIndex.
  static func cardBackRenderer(
    stylesheet: Stylesheet,
    revealingClozeAt index: Int
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(stylesheet: stylesheet, style: .body2)
    var localClozeAttributes = stylesheet.clozeAttributes
    localClozeAttributes[.foregroundColor] = stylesheet.colors
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
    var renderedCloze = 0
    renderer.renderFunctions[.cloze] = { node, _ in
      let attributes = renderedCloze == index ? localClozeAttributes : stylesheet.textAttributes
      renderedCloze += 1
      guard let cloze = node as? Cloze else { return NSAttributedString() }
      return NSAttributedString(string: String(cloze.hiddenText), attributes: attributes)
    }
    return renderer
  }
}

private let clozeRenderer: MarkdownAttributedStringRenderer = {
  var renderer = MarkdownAttributedStringRenderer.textOnly
  renderer.renderFunctions[.cloze] = { node, _ in
    guard let cloze = node as? Cloze else { return NSAttributedString() }
    return NSAttributedString(string: String(cloze.hiddenText))
  }
  return renderer
}()

private let defaultParagraphStyle: NSParagraphStyle = {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.alignment = .left
  return paragraphStyle
}()

extension Stylesheet {
  var textAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.body2,
      .foregroundColor: colors.onSurfaceColor.withAlphaComponent(alpha[.darkTextHighEmphasis] ?? 1),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var clozeAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.body2,
      .foregroundColor: colors.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .backgroundColor: UIColor(rgb: 0xF6E6F0),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var captionAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.caption,
      .foregroundColor: colors.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .kern: kern[.caption] ?? 1.0,
      .paragraphStyle: defaultParagraphStyle,
    ]
  }
}
