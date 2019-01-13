// Copyright © 2019 Brian's Brain. All rights reserved.

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

  public init(quote: BlockQuote) {
    self.quote = quote
    super.init()
  }

  enum CodingKeys: String, CodingKey {
    /// Encodes/decodes markdown text associated with `node`
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

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(quote.allMarkdown, forKey: .quote)
  }

  override public var type: CardTemplateType { return .quote }

  public let quote: BlockQuote

  public static func extract(from markdown: [Node]) -> [QuoteTemplate] {
    return markdown
      .map { $0.findNodes(where: { $0.type == .blockQuote }) }
      .joined()
      .map { QuoteTemplate(quote: $0 as! BlockQuote) } // swiftlint:disable:this force_cast
  }
}

extension QuoteTemplate: Equatable {
  public static func == (lhs: QuoteTemplate, rhs: QuoteTemplate) -> Bool {
    return lhs.quote.allMarkdown == rhs.quote.allMarkdown
  }
}
