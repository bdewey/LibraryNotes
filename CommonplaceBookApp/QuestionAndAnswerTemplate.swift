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
  public init(node: QuestionAndAnswer) {
    self.node = node
    super.init()
  }

  /// Decoding -- parses saved markdown and raises an error if it is not a single QuestionAndAnswer node.
  required convenience init(from decoder: Decoder) throws {
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      throw CommonErrors.noParsingRules
    }
    let container = try decoder.singleValueContainer()
    let markdown = try container.decode(String.self)
    let nodes = parsingRules.parse(markdown)
    if nodes.count == 1, let node = nodes[0] as? QuestionAndAnswer {
      self.init(node: node)
    } else {
      throw CommonErrors.markdownParseError
    }
  }

  /// The Q&A node.
  private let node: QuestionAndAnswer

  // MARK: - Codable

  /// Encoding: Writes the markdown into a single value container.
  public override func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(node.allMarkdown)
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
