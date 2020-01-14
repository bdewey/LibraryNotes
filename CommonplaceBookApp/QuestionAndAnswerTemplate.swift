// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let questionAndAnswer = ChallengeTemplateType(rawValue: "qanda", class: QuestionAndAnswerTemplate.self)
}

/// Generates challenges from QuestionAndAnswer minimarkdown nodes.
public final class QuestionAndAnswerTemplate: ChallengeTemplate {
  /// Designated initializer.
  public init?(node: QuestionAndAnswer) {
    self.node = node
    super.init()
  }

  required public init?(rawValue: String) {
    let nodes = ParsingRules.commonplace.parse(rawValue)
    if nodes.count == 1, let node = nodes[0] as? QuestionAndAnswer {
      self.node = node
      super.init()
    } else {
      return nil
    }
  }

  /// The Q&A node.
  private let node: QuestionAndAnswer
  public override var rawValue: String {
    return node.allMarkdown
  }

  // MARK: - Public

  public override var type: ChallengeTemplateType { return .questionAndAnswer }

  /// Extract templates from parsed minimarkdown.
  public static func extract(from nodes: [Node]) -> [QuestionAndAnswerTemplate] {
    return nodes.compactMap { node -> QuestionAndAnswerTemplate? in
      guard let qNode = node as? QuestionAndAnswer else { return nil }
      return QuestionAndAnswerTemplate(node: qNode)
    }
  }

  /// The single challenge from this template: Ourselves!
  public override var challenges: [Challenge] { return [self] }
}

extension QuestionAndAnswerTemplate: Challenge {
  public var challengeIdentifier: ChallengeIdentifier {
    return ChallengeIdentifier(templateDigest: templateIdentifier, index: 0)
  }

  public func challengeView(document: NoteStorage, properties: CardDocumentProperties) -> ChallengeView {
    let view = TwoSidedCardView(frame: .zero)
    let attributionNodes = properties.parsingRules.parse(properties.attributionMarkdown)
    if let attributionNode = attributionNodes.first {
      let attributionRenderer = MarkdownAttributedStringRenderer(
        textStyle: .subheadline,
        textColor: .secondaryLabel,
        extraAttributes: [.kern: 2.0]
      )
      view.context = attributionRenderer.render(node: attributionNode).trimmingTrailingWhitespace()
    } else {
      view.context = NSAttributedString(string: "")
    }
    var renderer = MarkdownAttributedStringRenderer(
      textStyle: .body
    )
    document.addImageRenderer(to: &renderer.renderFunctions)
    view.front = renderer.render(node: node.question).trimmingTrailingWhitespace()
    view.back = renderer.render(node: node.answer).trimmingTrailingWhitespace()
    return view
  }
}
