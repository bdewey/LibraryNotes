// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
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

  public static func extract(from buffer: IncrementalParsingBuffer) -> [QuoteTemplate] {
    guard let root = try? buffer.result.get() else { return [] }
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    return anchoredRoot
      .findNodes(where: { $0.type == .blockquote })
      .compactMap { node -> QuoteTemplate? in
        let chars = buffer[node.range]
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
    let quoteRenderer = RenderedMarkdown(
      textStyle: .body,
      parsingRules: properties.parsingRules
    )
    let (front, chapterAndVerse) = renderCardFront(with: quoteRenderer)
    view.front = front.trimmingTrailingWhitespace()
    let attributionRenderer = RenderedMarkdown(
      textStyle: .caption1,
      parsingRules: properties.parsingRules
    )
    let back = NSMutableAttributedString()
    back.append(front.trimmingTrailingWhitespace())
    back.append(NSAttributedString(string: "\n\n"))
    attributionRenderer.markdown = "—" + properties.attributionMarkdown + " " + chapterAndVerse
    back.append(attributionRenderer.attributedString.trimmingTrailingWhitespace())
    view.back = back
    return view
  }

  public func renderCardFront(
    with quoteRenderer: RenderedMarkdown
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    quoteRenderer.markdown = markdown
    let chapterAndVerse = quoteRenderer.attributedString.chapterAndVerseAnnotation ?? ""
    let front = quoteRenderer.attributedString.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}

extension QuoteTemplate: Equatable {
  public static func == (lhs: QuoteTemplate, rhs: QuoteTemplate) -> Bool {
    return lhs.markdown == rhs.markdown
  }
}
