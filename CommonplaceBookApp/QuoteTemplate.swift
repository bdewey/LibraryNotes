// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import MiniMarkdown

extension ChallengeTemplateType {
  public static let quote = ChallengeTemplateType(rawValue: "quote", class: QuoteTemplate.self)
}

public final class QuoteTemplate: ChallengeTemplate {
  // TODO: I should be able to share this with ClozeTemplate
  public enum Error: Swift.Error {
    /// Thrown when there are no ParsingRules in decoder.userInfo[.markdownParsingRules]
    /// when decoding a ClozeTemplate.
    case noParsingRules

    /// Thrown when encoded ClozeTemplate markdown does not decode to exactly one Node.
    case markdownParseError
  }

  public init(quote: BlockQuote) {
    self.quote = quote
    super.init()
  }

  enum CodingKeys: String, CodingKey {
    case quote
  }

  public required convenience init(from decoder: Decoder) throws {
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      throw Error.noParsingRules
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let markdown = try container.decode(String.self, forKey: .quote)
    let nodes = parsingRules.parse(markdown)
    if nodes.count == 1, let quote = nodes[0] as? BlockQuote {
      self.init(quote: quote)
    } else {
      throw Error.markdownParseError
    }
  }

  required convenience init(markdown description: String, parsingRules: ParsingRules) throws {
    let nodes = parsingRules.parse(description)
    if nodes.count == 1, let quote = nodes[0] as? BlockQuote {
      self.init(quote: quote)
    } else {
      throw Error.markdownParseError
    }
  }

  public override var asMarkdown: String {
    return quote.allMarkdown
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(quote.allMarkdown, forKey: .quote)
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

  public var templateIndex: Int { return 0 }

  public func challengeView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> ChallengeView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = stylesheet.attributedString(
      "Identify the source".uppercased(),
      style: .overline,
      emphasis: .darkTextMediumEmphasis
    )
    let quoteRenderer = RenderedMarkdown(
      stylesheet: stylesheet,
      style: .body2,
      parsingRules: properties.parsingRules
    )
    let (front, chapterAndVerse) = renderCardFront(with: quoteRenderer)
    view.front = front
    let attributionRenderer = RenderedMarkdown(
      stylesheet: stylesheet,
      style: .caption,
      parsingRules: properties.parsingRules
    )
    let back = NSMutableAttributedString()
    back.append(front)
    back.append(NSAttributedString(string: "\n"))
    attributionRenderer.markdown = "—" + properties.attributionMarkdown + " " + chapterAndVerse
    back.append(attributionRenderer.attributedString)
    view.back = back
    view.stylesheet = stylesheet
    return view
  }

  public func renderCardFront(
    with quoteRenderer: RenderedMarkdown
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    quoteRenderer.markdown = quote.allMarkdown
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
