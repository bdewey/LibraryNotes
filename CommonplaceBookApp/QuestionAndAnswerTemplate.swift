// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import UIKit

extension ChallengeTemplateType {
  public static let questionAndAnswer = ChallengeTemplateType(rawValue: "qanda", class: QuestionAndAnswerTemplate.self)
}

/// Generates challenges from QuestionAndAnswer minimarkdown nodes.
public final class QuestionAndAnswerTemplate: ChallengeTemplate {
  public required init?(rawValue: String) {
    self.markdown = rawValue
    super.init()
  }

  /// The Q&A node.
  private let markdown: String
  public override var rawValue: String { markdown }

  // MARK: - Public

  public override var type: ChallengeTemplateType { return .questionAndAnswer }

  public static func extract(from parsedString: ParsedString) -> [QuestionAndAnswerTemplate] {
    guard let root = try? parsedString.result.get() else { return [] }
    return AnchoredNode(node: root, startIndex: 0)
      .findNodes(where: { $0.type == .questionAndAnswer })
      .map {
        let chars = parsedString[$0.range]
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
    view.context = ParsedAttributedString(string: properties.attributionMarkdown, settings: .plainText(textStyle: .subheadline, textColor: .secondaryLabel, extraAttributes: [.kern: 2.0]))
    // TODO: Need to re-invent images :-(
//    document.addImageRenderer(to: &renderer.renderFunctions)
    let formattedString = ParsedAttributedString(string: markdown, settings: .plainText(textStyle: .body))
    if let node = try? formattedString.buffer.result.get() {
      let anchoredNode = AnchoredNode(node: node, startIndex: 0)
      if let question = anchoredNode.first(where: { $0.type == .qnaQuestion }) {
        view.front = formattedString.attributedSubstring(from: formattedString.visibleTextRange(forRawRange: question.range)).trimmingTrailingWhitespace()
      }
      if let answer = anchoredNode.first(where: { $0.type == .qnaAnswer }) {
        view.back = formattedString.attributedSubstring(from: formattedString.visibleTextRange(forRawRange: answer.range)).trimmingTrailingWhitespace()
      }
    }
    return view
  }
}
