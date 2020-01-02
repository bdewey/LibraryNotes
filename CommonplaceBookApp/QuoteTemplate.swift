// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let quote = ChallengeTemplateType(rawValue: "quote", class: QuoteTemplate.self)
}

public final class QuoteTemplate: ChallengeTemplate {
  public init(quote: BlockQuote) {
    self.quote = quote
    super.init()
  }

  public required convenience init(from decoder: Decoder) throws {
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      throw CommonErrors.noParsingRules
    }
    let container = try decoder.singleValueContainer()
    let markdown = try container.decode(String.self)
    let nodes = parsingRules.parse(markdown)
    if nodes.count == 1, let quote = nodes[0] as? BlockQuote {
      self.init(quote: quote)
    } else {
      throw CommonErrors.markdownParseError
    }
  }

  required convenience init(markdown description: String, parsingRules: ParsingRules) throws {
    let nodes = parsingRules.parse(description)
    if nodes.count == 1, let quote = nodes[0] as? BlockQuote {
      self.init(quote: quote)
    } else {
      throw CommonErrors.markdownParseError
    }
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(quote.allMarkdown)
  }

  public override var type: ChallengeTemplateType { return .quote }

  /// The quote template is itself a card.
  public override var challenges: [Challenge] { return [self] }

  public let quote: BlockQuote

  public static func extract(
    from markdown: [Node]
  ) -> [QuoteTemplate] {
    return markdown
      .map { $0.findNodes(where: { $0.type == .blockQuote }) }
      .joined()
      .map {
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
