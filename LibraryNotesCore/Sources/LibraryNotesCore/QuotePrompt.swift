// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import TextMarkupKit

public extension PromptType {
  static let quote = PromptType(rawValue: "prompt=quote", factory: QuotePromptFactory())
}

struct QuotePromptFactory: PromptCollectionFactory {
  func makePromptCollection(rawValue: String) -> (any PromptCollection)? {
    QuotePrompt(rawValue: rawValue)
  }
}

public struct QuotePrompt: PromptCollection {
  public init(rawValue: String) {
    self.markdown = rawValue
  }

  public var type: PromptType { .quote }

  /// The quote template is itself a card.
  public var prompts: [Prompt] { [self] }

  private let markdown: String
  public var rawValue: String {
    markdown
  }

  public static func extract(from parsedString: ParsedString) -> [QuotePrompt] {
    guard let root = try? parsedString.result.get() else { return [] }
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    return anchoredRoot
      .findNodes(where: { $0.type == .blockquote })
      .compactMap { node -> QuotePrompt? in
        let chars = parsedString[node.range]
        return QuotePrompt(rawValue: String(utf16CodeUnits: chars, count: chars.count))
      }
  }
}

extension QuotePrompt: Prompt {}

extension QuotePrompt: Equatable {
  public static func == (lhs: QuotePrompt, rhs: QuotePrompt) -> Bool {
    lhs.markdown == rhs.markdown
  }
}
