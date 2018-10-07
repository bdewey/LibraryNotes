// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import CommonplaceBook
import Foundation
import MiniMarkdown

public struct ClozeCard {
  public init(node: Node, clozeIndex: Int) {
    self.node = node
    self.clozeIndex = clozeIndex
  }

  public let node: Node

  // TODO: I don't actually do anything with the clozeIndex.

  public let clozeIndex: Int

  public var utterance: AVSpeechUtterance {
    let phrase = clozeRenderer.render(node: node)
    return AVSpeechUtterance(string: phrase)
  }

  public func context(with stylesheet: Stylesheet) -> NSAttributedString {
    let font = stylesheet.typographyScheme.overline
    let contextString = "Fill in the blank"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  public func cardFront(with stylesheet: Stylesheet) -> NSAttributedString {
    let cardFrontRenderer = MarkdownAttributedStringRenderer.cardFront(
      stylesheet: stylesheet,
      hideClozeAt: clozeIndex
    )
    return cardFrontRenderer.render(node: node)
  }

  public func cardBack(with stylesheet: Stylesheet) -> NSAttributedString {
    return MarkdownAttributedStringRenderer
      .cardBackRenderer(stylesheet: stylesheet, revealingClozeAt: clozeIndex)
      .render(node: node)
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
      return ClozeCard(node: node, clozeIndex: index)
    }
  }
}

extension ClozeCard: Card {
  var identifier: String {
    let suffix = clozeIndex > 0 ? "::\(clozeIndex)" : ""
    return String(node.slice.substring) + suffix
  }

  func cardView(with stylesheet: Stylesheet) -> CardView {
    return ClozeCardView(card: self, stylesheet: stylesheet)
  }
}

private let clozeRenderer: MarkdownStringRenderer = {
  var renderer = MarkdownStringRenderer()
  renderer.renderFunctions[.text] = { return String($0.slice.substring) }
  renderer.renderFunctions[.cloze] = { (node) in
    guard let cloze = node as? Cloze else { return "" }
    return String(cloze.hiddenText)
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
      .foregroundColor: colorScheme.onSurfaceColor.withAlphaComponent(alpha[.darkTextHighEmphasis] ?? 1),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var clozeAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.body2,
      .foregroundColor: colorScheme.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .backgroundColor: UIColor(rgb: 0xf6e6f0),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var captionAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.caption,
      .foregroundColor: colorScheme.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .kern: kern[.caption] ?? 1.0,
      .paragraphStyle: defaultParagraphStyle,
    ]
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

  static func captionRenderer(stylesheet: Stylesheet) -> MarkdownAttributedStringRenderer {
    var renderer = MarkdownAttributedStringRenderer(stylesheet: stylesheet)
    renderer.renderFunctions[.cloze] = { (node) in
      guard let cloze = node as? Cloze else { return NSAttributedString() }
      return NSAttributedString(
        string: String(cloze.hint),
        attributes: stylesheet.captionAttributes
      )
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
