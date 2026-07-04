// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import TextMarkupKit

public extension PromptType {
  static let questionAndAnswer = PromptType(rawValue: "prompt=qanda", factory: QuestionAndAnswerPromptFactory())
}

struct QuestionAndAnswerPromptFactory: PromptCollectionFactory {
  func makePromptCollection(rawValue: String) -> (any PromptCollection)? {
    QuestionAndAnswerPrompt(rawValue: rawValue)
  }
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

  public var type: PromptType { .questionAndAnswer }

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
  public var prompts: [Prompt] { [self] }
}

extension QuestionAndAnswerPrompt: Prompt {}
