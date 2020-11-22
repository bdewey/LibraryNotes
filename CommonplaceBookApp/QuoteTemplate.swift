// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import UIKit

extension ChallengeTemplateType {
  public static let quote = ChallengeTemplateType(rawValue: "quote", class: QuoteTemplate.self)
}

public final class QuoteTemplate: ChallengeTemplate {
  public required init?(rawValue: String) {
    markdown = rawValue
    super.init()
  }

  public override var type: ChallengeTemplateType { return .quote }

  /// The quote template is itself a card.
  public override var challenges: [Challenge] { return [self] }

  private let markdown: String
  public override var rawValue: String {
    return markdown
  }

  public static func extract(from parsedString: ParsedString) -> [QuoteTemplate] {
    guard let root = try? parsedString.result.get() else { return [] }
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    return anchoredRoot
      .findNodes(where: { $0.type == .blockquote })
      .compactMap { node -> QuoteTemplate? in
        let chars = parsedString[node.range]
        return QuoteTemplate(rawValue: String(utf16CodeUnits: chars, count: chars.count))
      }
  }
}

extension QuoteTemplate: Challenge {
  public var identifier: String {
    return markdown
  }

  public var challengeIdentifier: ChallengeIdentifier {
    return ChallengeIdentifier(templateDigest: templateIdentifier, index: 0)
  }

  public func challengeView(
    document: NoteStorage,
    properties: CardDocumentProperties
  ) -> ChallengeView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = NSAttributedString(
      string: "Identify the source".uppercased(),
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .subheadline),
        .foregroundColor: UIColor.secondaryLabel,
        .kern: 2.0,
      ]
    )
    let (front, chapterAndVerse) = renderCardFront()
    view.front = front.trimmingTrailingWhitespace()
    let attribution = ParsedAttributedString(string: "—" + properties.attributionMarkdown + " " + chapterAndVerse, settings: .plainText(textStyle: .caption1))
    let back = NSMutableAttributedString()
    back.append(front.trimmingTrailingWhitespace())
    back.append(NSAttributedString(string: "\n\n"))
    back.append(attribution.trimmingTrailingWhitespace())
    view.back = back
    return view
  }

  public func renderCardFront(
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    let renderedMarkdown = ParsedAttributedString(string: markdown, settings: .plainText(textStyle: .body))
    let chapterAndVerse = renderedMarkdown.chapterAndVerseAnnotation ?? ""
    let front = renderedMarkdown.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}

extension QuoteTemplate: Equatable {
  public static func == (lhs: QuoteTemplate, rhs: QuoteTemplate) -> Bool {
    return lhs.markdown == rhs.markdown
  }
}
