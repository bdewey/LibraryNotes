// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let questionAndAnswer = ChallengeTemplateType(rawValue: "qanda", class: QuestionAndAnswerTemplate.self)
}

/// Generates challenges from QuestionAndAnswer minimarkdown nodes.
public final class QuestionAndAnswerTemplate: ChallengeTemplate {
  public required init?(rawValue: String) {
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

  public static func extract(from buffer: IncrementalParsingBuffer) -> [QuestionAndAnswerTemplate] {
    guard let root = try? buffer.result.get() else { return [] }
    return AnchoredNode(node: root, startIndex: 0)
      .findNodes(where: { $0.type == .questionAndAnswer })
      .map {
        let chars = buffer[$0.range]
        return String(utf16CodeUnits: chars, count: chars.count)
      }
      .compactMap {
        QuestionAndAnswerTemplate(rawValue: $0)
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
