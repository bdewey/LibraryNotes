// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import CommonplaceBook
import Foundation
import MiniMarkdown
import TextBundleKit

public struct ClozeCard: Codable {
  public init(markdown: String, clozeIndex: Int) {
    self.markdown = markdown
    self.clozeIndex = clozeIndex
  }

  public let markdown: String
  public let clozeIndex: Int

  public func cardFrontRenderer(stylesheet: Stylesheet) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.cardFront(
      stylesheet: stylesheet,
      hideClozeAt: clozeIndex
    )
  }

  public func cardBackRenderer(stylesheet: Stylesheet) -> MarkdownAttributedStringRenderer {
    return MarkdownAttributedStringRenderer.cardBackRenderer(
      stylesheet: stylesheet,
      revealingClozeAt: clozeIndex
    )
  }
}

extension ClozeCard {
  public static func makeCards(from markdown: [Node]) -> [ClozeCard] {
    let clozes = markdown
      .map { $0.findNodes(where: { $0.type == .cloze }) }
      .joined()
      .compactMap { $0.findFirstAncestor(where: { $0.type == .paragraph || $0.type == .listItem }) }
    DDLogDebug("Found \(clozes.count) clozes")
    var indexForNode: [ObjectIdentifier: Int] = [:]
    return clozes.map { (node) in
      let index = indexForNode[ObjectIdentifier(node), default: 0]
      indexForNode[ObjectIdentifier(node)] = index + 1
      return ClozeCard(markdown: node.allMarkdown, clozeIndex: index)
    }
  }
}

extension ClozeCard: Card {
  var identifier: String {
    let suffix = clozeIndex > 0 ? "::\(clozeIndex)" : ""
    return markdown + suffix
  }

  func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView {
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
