// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import Foundation
import MiniMarkdown

/// A Card for remembering a sentence with a word/phrase removed and optionally replaced with
/// a hint. The removed word/phrase is a "cloze".
///
/// See https://en.wikipedia.org/wiki/Cloze_test
public struct ClozeCard {
  /// Designated initializer.
  ///
  /// - parameter markdown: The markdown content that contains at least one cloze.
  /// - parameter closeIndex: The index of the cloze in `markdown` to remove when testing.
  public init(template: ClozeTemplate, markdown: String, clozeIndex: Int) {
    self.markdown = markdown
    self.clozeIndex = clozeIndex
    self.challengeIdentifier = ChallengeIdentifier(
      templateDigest: template.templateIdentifier,
      index: clozeIndex
    )
  }

  /// The markdown content that contains at least one cloze.
  public let markdown: String

  /// The index of the cloze in `markdown` to remove when testing.
  public let clozeIndex: Int

  public var challengeIdentifier: ChallengeIdentifier

  /// Creates a renderer that will render `markdown` with the cloze at `clozeIndex` removed,
  /// replaced with a hint if present, and highlighted.
  public func cardFrontRenderer() -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.cardFront(
      hideClozeAt: clozeIndex
    )
  }
}

extension ClozeCard: Challenge {
  public var identifier: String {
    let suffix = clozeIndex > 0 ? "::\(clozeIndex)" : ""
    return markdown + suffix
  }

  public func challengeView(
    document: UIDocument,
    properties: CardDocumentProperties
  ) -> ChallengeView {
    let cardView = TwoSidedCardView(frame: .zero)
    let nodes = properties.parsingRules.parse(markdown)
    assert(nodes.count == 1)
    let node = nodes[0]
    cardView.context = context()
    let (front, chapterAndVerse) = cardFront(node: node)
      .decomposedChapterAndVerseAnnotation
    cardView.front = front
    let back = NSMutableAttributedString()
    back.append(cardBack(node: node).removingChapterAndVerseAnnotation())
    if !properties.attributionMarkdown.isEmpty {
      back.append(NSAttributedString(string: "\n"))
      let attributionRenderer = RenderedMarkdown(
        textStyle: .caption1,
        parsingRules: properties.parsingRules
      )
      attributionRenderer.markdown = "—" + properties.attributionMarkdown + " " + chapterAndVerse
      back.append(attributionRenderer.attributedString)
    }
    cardView.back = back
    return cardView
  }

  func utterance(node: Node) -> AVSpeechUtterance {
    let phrase = clozeRenderer.render(node: node).string
    let utterance = AVSpeechUtterance(string: phrase)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
    return utterance
  }

  func context() -> NSAttributedString {
    let font = UIFont.preferredFont(forTextStyle: .subheadline)
    let contextString = "Fill in the blank"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor.secondaryLabel]
    )
  }

  func cardFront(node: Node) -> NSAttributedString {
    return cardFrontRenderer().render(node: node)
  }

  func cardBack(node: Node) -> NSAttributedString {
    return MarkdownAttributedStringRenderer
      .cardBackRenderer(revealingClozeAt: clozeIndex)
      .render(node: node)
  }
}

extension MarkdownAttributedStringRenderer {
  /// Builds a renderer that will replace the cloze at clozeIndex with its hint and
  /// highlight the cloze.
  static func cardFront(
    hideClozeAt index: Int
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(textStyle: .body)
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
          var attributes = Attributes.cloze
          attributes[.foregroundColor] = UIColor.clear
          return NSAttributedString(string: String(cloze.hiddenText), attributes: attributes)
        } else {
          return NSAttributedString(
            string: String(cloze.hint),
            attributes: Attributes.cloze
          )
        }
      } else {
        return NSAttributedString(
          string: String(cloze.hiddenText),
          attributes: Attributes.text
        )
      }
    }
    return renderer
  }

  /// Builds a renderer that will show and highlight the cloze at clozeIndex.
  static func cardBackRenderer(
    revealingClozeAt index: Int
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(textStyle: .body)
    var localClozeAttributes = Attributes.cloze
    localClozeAttributes[.foregroundColor] = UIColor.label
    var renderedCloze = 0
    renderer.renderFunctions[.cloze] = { node, _ in
      let attributes = renderedCloze == index ? localClozeAttributes : Attributes.text
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

/// A collection of common NSAttributedString attributes
private enum Attributes {
  static var text: [NSAttributedString.Key: Any] {
    return [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
  }

  static var cloze: [NSAttributedString.Key: Any] {
    return [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.secondaryLabel,
      .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3),
    ]
  }

  static var caption: [NSAttributedString.Key: Any] {
    return [
      .font: UIFont.preferredFont(forTextStyle: .caption1),
      .foregroundColor: UIColor.secondaryLabel,
    ]
  }
}
