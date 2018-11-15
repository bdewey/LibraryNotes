// Copyright © 2018 Brian's Brain. All rights reserved.

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

  /// Creates a renderer that will render `markdown` with the cloze at `clozeIndex`
  /// present and highlighted.
  public func cardBackRenderer(stylesheet: Stylesheet) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.cardBackRenderer(
      stylesheet: stylesheet,
      revealingClozeAt: clozeIndex
    )
  }
}

extension ClozeCard: Card {

  public var identifier: String {
    let suffix = clozeIndex > 0 ? "::\(clozeIndex)" : ""
    return markdown + suffix
  }

  public func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView {
    return ClozeCardView(card: self, parseableDocument: parseableDocument, stylesheet: stylesheet)
  }
}

extension MarkdownAttributedStringRenderer {
  init(stylesheet: Stylesheet) {
    self.init()
    renderFunctions[.text] = { (node) in
      return NSAttributedString(
        string: String(node.slice.substring),
        attributes: stylesheet.textAttributes
      )
    }
  }

  /// Builds a renderer that will replace the cloze at clozeIndex with its hint and
  /// highlight the cloze.
  static func cardFront(
    stylesheet: Stylesheet,
    hideClozeAt index: Int
  ) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(stylesheet: stylesheet)
    var renderedCloze = 0
    renderer.renderFunctions[.cloze] = { (node) in
      guard let cloze = node as? Cloze else { return NSAttributedString() }
      let shouldHide = renderedCloze == index
      renderedCloze += 1
      if shouldHide {
        return NSAttributedString(
          string: String(cloze.hint),
          attributes: stylesheet.clozeAttributes
        )
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
    var renderer = MarkdownAttributedStringRenderer(stylesheet: stylesheet)
    var localClozeAttributes = stylesheet.clozeAttributes
    localClozeAttributes[.foregroundColor] = stylesheet.colorScheme
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
    var renderedCloze = 0
    renderer.renderFunctions[.cloze] = { (node) in
      let attributes = renderedCloze == index ? localClozeAttributes : stylesheet.textAttributes
      renderedCloze += 1
      guard let cloze = node as? Cloze else { return NSAttributedString() }
      return NSAttributedString(string: String(cloze.hiddenText), attributes: attributes)
    }
    return renderer
  }
}
