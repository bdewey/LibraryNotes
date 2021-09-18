// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import TextMarkupKit
import UIKit

public extension PromptType {
  static let questionAndAnswer = PromptType(rawValue: "prompt=qanda", class: QuestionAndAnswerPrompt.self)
}

/// Generates prompts from QuestionAndAnswer minimarkdown nodes.
public struct QuestionAndAnswerPrompt: PromptCollection {
  public init(rawValue: String) {
    self.markdown = rawValue
  }

  /// The Q&A node.
  private let markdown: String
  public var rawValue: String { markdown }

  // MARK: - Public

  public var type: PromptType { return .questionAndAnswer }

  public static func extract(from parsedString: ParsedString) -> [QuestionAndAnswerPrompt] {
    guard let root = try? parsedString.result.get() else { return [] }
    return AnchoredNode(node: root, startIndex: 0)
      .findNodes(where: { $0.type == .questionAndAnswer })
      .map {
        let chars = parsedString[$0.range]
        return String(utf16CodeUnits: chars, count: chars.count)
      }
      .compactMap {
        QuestionAndAnswerPrompt(rawValue: $0)
      }
  }

  /// The single prompt from this template: Ourselves!
  public var prompts: [Prompt] { return [self] }
}

extension QuestionAndAnswerPrompt: Prompt {
  public func promptView(database: NoteDatabase, properties: CardDocumentProperties) -> PromptView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = ParsedAttributedString(string: properties.attributionMarkdown, style: .plainText(textStyle: .subheadline, textColor: .secondaryLabel, kern: 2.0))
    let formattedString = ParsedAttributedString(
      string: markdown,
      style: .plainText(textStyle: .body, imageStorage: BoundNote(identifier: properties.documentName, database: database))
    )
    if let node = try? formattedString.rawString.result.get() {
      let anchoredNode = AnchoredNode(node: node, startIndex: 0)
      if let question = anchoredNode.first(where: { $0.type == .qnaQuestion }) {
        view.front = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: question.range)).trimmingTrailingWhitespace()
      }
      if let answer = anchoredNode.first(where: { $0.type == .qnaAnswer }) {
        view.back = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: answer.range)).trimmingTrailingWhitespace()
      }
    }
    return view
  }
}
