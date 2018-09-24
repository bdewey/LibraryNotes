// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MiniMarkdown

struct ClozeCard {
  init(node: Node, clozeIndex: Int) {
    self.node = node
    self.clozeIndex = clozeIndex
  }

  private let node: Node

  // TODO: I don't actually do anything with the clozeIndex.

  private let clozeIndex: Int

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
    let combinedClozeAndCaption = NSMutableAttributedString()
    combinedClozeAndCaption.append(cardFrontRenderer.render(node: node))
    combinedClozeAndCaption.append(NSAttributedString(string: "\n"))
    combinedClozeAndCaption.append(captionRenderer.render(node: node))
    return combinedClozeAndCaption
  }

  public func cardBack(with stylesheet: Stylesheet) -> NSAttributedString {
    return cardBackRenderer.render(node: node)
  }
}

extension ClozeCard {
  static func makeCards(from markdown: [Node]) -> [ClozeCard] {
    let nodePaths = markdown
      .map { $0.findNodePaths(toBlocksMatching: { $0.type == .cloze }) }
    let nodes = zip(markdown, nodePaths).compactMap { (zipped) -> Node? in
      let (node, allPaths) = zipped
      if let firstPath = allPaths.first {
        var lastEligibleNode: Node?
        node.walkNodePath(firstPath, block: { (possibleContainer) in
          if possibleContainer.type == .paragraph || possibleContainer.type == .listItem {
            lastEligibleNode = possibleContainer
          }
        })
        return lastEligibleNode
      } else {
        return nil
      }
    }
    return nodes.map { ClozeCard(node: $0, clozeIndex: 0) }
  }
}

extension ClozeCard: Card {
  var identifier: String {
    return String(node.slice.substring)
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

private let textAttributes: [NSAttributedString.Key: Any] = [
  .font: Stylesheet.hablaEspanol.typographyScheme.body2,
  .foregroundColor: UIColor(white: 0, alpha: 0.87),
  .paragraphStyle: defaultParagraphStyle,
]

private let clozeAttributes: [NSAttributedString.Key: Any] = [
  .font: Stylesheet.hablaEspanol.typographyScheme.body2,
  .foregroundColor: UIColor(rgb: 0xf6e6f0),
  .backgroundColor: UIColor(rgb: 0xf6e6f0),
  .paragraphStyle: defaultParagraphStyle,
]

private let captionAttributes: [NSAttributedString.Key: Any] = [
  .font: Stylesheet.hablaEspanol.typographyScheme.caption,
  .foregroundColor: UIColor(white: 0, alpha: 0.6),
  .kern: 0.4,
  .paragraphStyle: defaultParagraphStyle,
]

private let baseRenderer: MarkdownAttributedStringRenderer = {
  var renderer = MarkdownAttributedStringRenderer()
  renderer.renderFunctions[.text] = { (node) in
    return NSAttributedString(string: String(node.slice.substring), attributes: textAttributes)
  }
  return renderer
}()

private let cardFrontRenderer: MarkdownAttributedStringRenderer = {
  var renderer = baseRenderer
  renderer.renderFunctions[.cloze] = { (node) in
    guard let cloze = node as? Cloze else { return NSAttributedString() }
    return NSAttributedString(string: String(cloze.hiddenText), attributes: clozeAttributes)
  }
  return renderer
}()

private let captionRenderer: MarkdownAttributedStringRenderer = {
  var renderer = MarkdownAttributedStringRenderer()
  renderer.renderFunctions[.cloze] = { (node) in
    guard let cloze = node as? Cloze else { return NSAttributedString() }
    return NSAttributedString(string: String(cloze.hint), attributes: captionAttributes)
  }
  return renderer
}()

private let cardBackRenderer: MarkdownAttributedStringRenderer = {
  var renderer = baseRenderer
  var localClozeAttributes = clozeAttributes
  localClozeAttributes[.foregroundColor] = UIColor(white: 0, alpha: 0.87)
  renderer.renderFunctions[.cloze] = { (node) in
    guard let cloze = node as? Cloze else { return NSAttributedString() }
    return NSAttributedString(string: String(cloze.hiddenText), attributes: localClozeAttributes)
  }
  return renderer
}()
