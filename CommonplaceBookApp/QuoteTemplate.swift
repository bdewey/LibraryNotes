// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import MiniMarkdown

extension CardTemplateType {
  public static let quote = CardTemplateType(rawValue: "quote", class: QuoteTemplate.self)
}

public final class QuoteTemplate: CardTemplate {

  // TODO: I should be able to share this with ClozeTemplate
  public enum Error: Swift.Error {
    /// Thrown when there are no ParsingRules in decoder.userInfo[.markdownParsingRules]
    /// when decoding a ClozeTemplate.
    case noParsingRules

    /// Thrown when encoded ClozeTemplate markdown does not decode to exactly one Node.
    case markdownParseError
  }

  public init(quote: BlockQuote, attributionMarkdown: String) {
    self.quote = quote
    self.attributionMarkdown = attributionMarkdown
    super.init()
  }

  enum CodingKeys: String, CodingKey {
    case attribution
    case quote
  }

  public required convenience init(from decoder: Decoder) throws {
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      throw Error.noParsingRules
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let markdown = try container.decode(String.self, forKey: .quote)
    let attributionMarkdown = try container.decode(String.self, forKey: .attribution)
    let nodes = parsingRules.parse(markdown)
    if nodes.count == 1, let quote = nodes[0] as? BlockQuote {
      self.init(quote: quote, attributionMarkdown: attributionMarkdown)
    } else {
      throw Error.markdownParseError
    }
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(quote.allMarkdown, forKey: .quote)
    try container.encode(attributionMarkdown, forKey: .attribution)
  }

  override public var type: CardTemplateType { return .quote }

  /// The quote template is itself a card.
  public override var cards: [Card] { return [self] }

  public let quote: BlockQuote
  public let attributionMarkdown: String

  public static func extract(
    from markdown: [Node],
    attributionMarkdown: String
  ) -> [QuoteTemplate] {
    return markdown
      .map { $0.findNodes(where: { $0.type == .blockQuote }) }
      .joined()
      .map {
        // swiftlint:disable:next force_cast
        QuoteTemplate(quote: $0 as! BlockQuote, attributionMarkdown: attributionMarkdown)
      }
  }
}

extension QuoteTemplate: Card {
  public var identifier: String {
    return quote.allMarkdown
  }

  public func cardView(
    parseableDocument: ParseableDocument,
    stylesheet: Stylesheet
  ) -> CardView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = stylesheet.attributedString(
      "Identify the source".uppercased(),
      style: .overline,
      emphasis: .darkTextMediumEmphasis
    )
    let quoteRenderer = makeQuoteRenderer(
      stylesheet: stylesheet,
      style: .body2,
      parsingRules: parseableDocument.parsingRules
    )
    quoteRenderer.markdown = quote.allMarkdown
    view.front = quoteRenderer.attributedString
    let attributionRenderer = makeQuoteRenderer(
      stylesheet: stylesheet,
      style: .caption,
      parsingRules: parseableDocument.parsingRules
    )
    let back = NSMutableAttributedString()
    back.append(quoteRenderer.attributedString)
    back.append(NSAttributedString(string: "\n"))
    attributionRenderer.markdown = "—" + attributionMarkdown
    back.append(attributionRenderer.attributedString)
    view.back = back
    view.stylesheet = stylesheet
    return view
  }
}

private func makeQuoteRenderer(
  stylesheet: Stylesheet,
  style: Stylesheet.Style,
  parsingRules: ParsingRules
) -> RenderedMarkdown {
  var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
  formatters[.emphasis] = { $1.italic = true }
  formatters[.bold] = { $1.bold = true }
  var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
  renderers[.delimiter] = { (_, _) in return NSAttributedString() }
  let renderer = RenderedMarkdown(
    parsingRules: ParsingRules(),
    formatters: formatters,
    renderers: renderers
  )
  renderer.defaultAttributes = NSAttributedString.Attributes(
    stylesheet.typographyScheme[style]
  )
  renderer.defaultAttributes.kern = stylesheet.kern[style] ?? 1.0
  renderer.defaultAttributes.alignment = .left
  return renderer
}

extension QuoteTemplate: Equatable {
  public static func == (lhs: QuoteTemplate, rhs: QuoteTemplate) -> Bool {
    return lhs.quote.allMarkdown == rhs.quote.allMarkdown
  }
}
