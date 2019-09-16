// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let questionAndAnswer = ChallengeTemplateType(rawValue: "qanda", class: QuestionAndAnswerTemplate.self)
}

public final class QuestionAndAnswerTemplate: ChallengeTemplate {
  public init(node: QuestionAndAnswer) {
    self.node = node
    super.init()
  }

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

  private let node: QuestionAndAnswer

  // MARK: - Codable

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(node.allMarkdown)
  }

  // MARK: - Public

  public override var type: ChallengeTemplateType { return .questionAndAnswer }

  public static func extract(from nodes: [Node]) -> [QuestionAndAnswerTemplate] {
    return nodes.compactMap { node -> QuestionAndAnswerTemplate? in
      guard let qNode = node as? QuestionAndAnswer else { return nil }
      return QuestionAndAnswerTemplate(node: qNode)
    }
  }

  public override var challenges: [Challenge] { return [self] }
}

extension QuestionAndAnswerTemplate: Challenge {
  public var challengeIdentifier: ChallengeIdentifier {
    return ChallengeIdentifier(templateDigest: templateIdentifier, index: 0)
  }

  public func challengeView(document: UIDocument, properties: CardDocumentProperties) -> ChallengeView {
    let view = TwoSidedCardView(frame: .zero)
    let attributionNodes = properties.parsingRules.parse(properties.attributionMarkdown)
    let attributionR2 = MarkdownAttributedStringRenderer(textStyle: .subheadline, textColor: .secondaryLabel, extraAttributes: [.kern: 2.0])
    if let attributionNode = attributionNodes.first {
      view.context = attributionR2.render(node: attributionNode).trimmingTrailingWhitespace()
    } else {
      view.context = NSAttributedString(string: "")
    }
    let renderer = MarkdownAttributedStringRenderer(
      textStyle: .body
    )
    view.front = renderer.render(node: node.question).trimmingTrailingWhitespace()
    view.back = renderer.render(node: node.answer).trimmingTrailingWhitespace()
    return view
  }

  public func renderCardFront(
    with quoteRenderer: RenderedMarkdown
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    quoteRenderer.markdown = String(node.allMarkdown)
    let chapterAndVerse = quoteRenderer.attributedString.chapterAndVerseAnnotation ?? ""
    let front = quoteRenderer.attributedString.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}
