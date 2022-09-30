// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import TextMarkupKit
import UIKit

public extension PromptType {
  static let quote = PromptType(rawValue: "prompt=quote", class: QuotePrompt.self)
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

extension QuotePrompt: Prompt {
  public func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = NSAttributedString(
      string: "Identify the source".uppercased(),
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .subheadline),
        .foregroundColor: UIColor.secondaryLabel,
        .kern: 2.0,
      ]
    )
    let (front, chapterAndVerse) = renderCardFront(imageStorage: NoteScopedImageStorage(identifier: properties.documentName, database: database))
    view.front = front.trimmingTrailingWhitespace()
    let attribution = ParsedAttributedString(string: "—" + properties.attributionMarkdown + " " + chapterAndVerse, style: .plainText(textStyle: .caption1))
    let back = NSMutableAttributedString()
    back.append(front.trimmingTrailingWhitespace())
    // Make sure the string we append gets a paragraph style
    back.append(ParsedAttributedString(string: "\n\n", style: .plainText(textStyle: .caption1)))
    back.append(attribution.trimmingTrailingWhitespace())
    view.back = back
    return view
  }

  public func renderCardFront(
    imageStorage: NoteScopedImageStorage?
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    let renderedMarkdown = ParsedAttributedString(string: markdown, style: .plainText(textStyle: .body, imageStorage: imageStorage))
    let chapterAndVerse = renderedMarkdown.chapterAndVerseAnnotation ?? ""
    let front = renderedMarkdown.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}

extension QuotePrompt: Equatable {
  public static func == (lhs: QuotePrompt, rhs: QuotePrompt) -> Bool {
    lhs.markdown == rhs.markdown
  }
}
