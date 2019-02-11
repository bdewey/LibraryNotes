// Copyright © 2018-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

extension Node {
  /// Returns true if the node is a table with a specified number of columns.
  func isTable(withColumnCount columnCount: Int) -> Bool {
    guard let table = self as? MiniMarkdown.Table else { return false }
    return table.columnCount == columnCount
  }
}

/// Helpers that extract VocabularyAssociation data from a table row.
extension MiniMarkdown.TableRow {
  /// Returns the Spanish word in the row.
  fileprivate var spanish: String {
    return String(
      MarkdownAttributedStringRenderer.textOnly
        .render(node: cells[0]).string.strippingLeadingAndTrailingWhitespace
    )
  }

  /// Returns true if we are supposed to test spelling.
  fileprivate var testSpelling: Bool {
    return cells[0]
      .findNodes(where: { $0.type == .hashtag })
      .contains(where: { $0.slice.substring == "#spelling" })
  }

  fileprivate var english: String {
    return String(
      cells[1].slice.substring.strippingLeadingAndTrailingWhitespace
    )
  }
}

extension CardTemplateType {
  public static let vocabularyAssociation = CardTemplateType(
    rawValue: "vocabularyAssociation",
    class: VocabularyAssociation.self
  )
}

/// Represents and association of a Spanish to an English word. This association generates
/// 2 or 3 cards, which are specific things to remember:
///
/// - Given the Spanish word, what is the English word?
/// - Given the Engish word, what is the Spanish word?
/// - How do you spell the Spanish word? (optional)
public final class VocabularyAssociation: CardTemplate {
  public override var type: CardTemplateType { return .vocabularyAssociation }

  /// The Spanish word.
  let spanish: String

  /// The associated English word. This can be either a word, just an image, or an image with a
  /// caption.
  var english: String

  /// Whether or not to test spelling of this word.
  var testSpelling: Bool

  enum CodingKeys: String, CodingKey {
    case spanish
    case english
    case testSpelling
  }

  /// Constructs an association given just an English word.
  init(spanish: String, english: String, testSpelling: Bool = false) {
    self.spanish = spanish
    self.english = english
    self.testSpelling = testSpelling
    super.init()
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.spanish = try container.decode(String.self, forKey: .spanish)
    self.english = try container.decode(String.self, forKey: .english)
    self.testSpelling = try container.decode(Bool.self, forKey: .testSpelling)
    try super.init(from: decoder)
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(spanish, forKey: .spanish)
    try container.encode(english, forKey: .english)
    try container.encode(testSpelling, forKey: .testSpelling)
  }

  /// Loads cards from a Markdown string.
  ///
  /// This function looks for the first table in the string that has two columns.
  /// Each row in the table is a card, with the first column having the spanish word and the second
  /// column having the English word.
  ///
  /// - parameter markdown: The markdown-formatted string.
  /// - returns: A tuple of VocabularyCard structures extracted from the string and the range
  ///            in `markdown` that the string came from.
  public static func makeAssociations(
    from markdown: String
  ) -> ([VocabularyAssociation], Range<String.Index>) {
    // TODO: No way to customize these parsing rules
    let blocks = MiniMarkdown.ParsingRules().parse(markdown)
    return makeAssociations(from: blocks)
  }

  public static func makeAssociations(
    from blocks: [Node]
  ) -> ([VocabularyAssociation], Range<String.Index>) {
    let maybeTable = blocks.first { $0.isTable(withColumnCount: 2) }
    guard let table = maybeTable as? MiniMarkdown.Table else {
      return ([], "".completeRange)
    }
    var cards: [VocabularyAssociation] = []
    for row in table.rows {
      let english = row.english
      cards.append(
        VocabularyAssociation(
          spanish: row.spanish,
          english: english,
          testSpelling: row.testSpelling
        )
      )
    }
    return (cards, table.slice.range)
  }

  /// Creates cards from this association.
  public override var cards: [Card] {
    var cards: [Card] = [
      VocabularyAssociationCard(vocabularyAssociation: self, promptWithSpanish: true),
      VocabularyAssociationCard(vocabularyAssociation: self, promptWithSpanish: false),
    ]
    if testSpelling {
      cards.append(VocabularyAssociationSpellingCard(vocabularyAssociation: self))
    }
    return cards
  }
}

extension VocabularyAssociation: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      VocabularyAssociation.self,
      children: [
      "spanish": spanish,
      "english": english,
      "testSpelling": testSpelling,
    ])
  }
}

extension String {
  fileprivate mutating func appendCellValue(_ value: String, paddedLength: Int) {
    self += " "
    self += value
    let paddingCount = max(0, paddedLength - value.count)
    if paddingCount > 0 {
      self += String(repeating: " ", count: paddingCount)
    }
    self += " |"
  }
}

extension VocabularyAssociation {
  var encodedMetadata: String {
    return testSpelling ? " #spelling" : ""
  }
}

extension Array where Element == VocabularyAssociation {
  /// Formats the cards as a Markdown string.
  func makeTable() -> String {
    let columnHeaders = ["Spanish", "Engish"]
    var columnWidths = columnHeaders.map { $0.count }
    for card in self {
      columnWidths[0] = Swift.max(columnWidths[0], card.spanish.count + card.encodedMetadata.count)
      columnWidths[1] = Swift.max(columnWidths[1], card.english.description.count)
    }
    var markdown = "|"
    for (index, header) in columnHeaders.enumerated() {
      markdown.appendCellValue(header, paddedLength: columnWidths[index])
    }
    markdown += "\n|"
    for index in 0 ..< 2 {
      markdown.appendCellValue(
        String(repeating: "-", count: columnWidths[index]),
        paddedLength: columnWidths[index]
      )
    }
    markdown += "\n"
    for card in self {
      markdown += "|"
      markdown.appendCellValue(card.spanish + card.encodedMetadata, paddedLength: columnWidths[0])
      markdown.appendCellValue(card.english.description, paddedLength: columnWidths[1])
      markdown += "\n"
    }
    return markdown
  }
}
