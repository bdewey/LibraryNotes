// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let quote = ChallengeTemplateType(rawValue: "quote", class: QuoteTemplate.self)
}

public final class QuoteTemplate: ChallengeTemplate {
  public init?(quote: BlockQuote) {
    self.quote = quote
    super.init()
  }

  public required init?(rawValue: String) {
    let nodes = ParsingRules.commonplace.parse(rawValue)
    guard nodes.count == 1, let quote = nodes[0] as? BlockQuote else {
      return nil
    }
    self.quote = quote
    super.init()
  }

  public override var type: ChallengeTemplateType { return .quote }

  /// The quote template is itself a card.
  public override var challenges: [Challenge] { return [self] }

  public let quote: BlockQuote
  public override var rawValue: String {
    return quote.allMarkdown
  }

  public static func extract(
    from markdown: [Node]
  ) -> [QuoteTemplate] {
    return markdown
      .map { $0.findNodes(where: { $0.type == .blockQuote }) }
      .joined()
      .compactMap {
        // swiftlint:disable:next force_cast
        QuoteTemplate(quote: $0 as! BlockQuote)
      }
  }
}

extension QuoteTemplate: Challenge {
  public var identifier: String {
    return quote.allMarkdown
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
    quoteRenderer.markdown = String(quote.allMarkdown)
    let chapterAndVerse = quoteRenderer.attributedString.chapterAndVerseAnnotation ?? ""
    let front = quoteRenderer.attributedString.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}

extension QuoteTemplate: Equatable {
  public static func == (lhs: QuoteTemplate, rhs: QuoteTemplate) -> Bool {
    return lhs.quote.allMarkdown == rhs.quote.allMarkdown
  }
}
