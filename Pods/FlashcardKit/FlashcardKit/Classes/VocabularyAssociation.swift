// Copyright © 2018 Brian's Brain. All rights reserved.

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
extension MiniMarkdown.NewTableRow {

  /// Returns the Spanish word in the row.
  fileprivate var spanish: String {
    return String(
      textOnlyRenderer.render(node: children[0]).strippingLeadingAndTrailingWhitespace
    )
  }

  /// Returns true if we are supposed to test spelling.
  fileprivate var testSpelling: Bool {
    return children[0]
      .findNodes(where: { $0.type == .hashtag })
      .contains(where: { $0.slice.substring == "#spelling" })
  }

  fileprivate func english(loadingImagesFrom document: TextBundleDocument) -> WordOrImage? {
    guard var wordOrImage = WordOrImage(String(children[1].contents)) else { return nil }
    if case WordOrImage.image(caption: let caption, image: var bundleImage) = wordOrImage,
      let key = bundleImage.key {
      let components = key.split(separator: "/")
      if let data = try? document.data(for: String(components.last!), at: components.dropLast().map({ String($0) })),
        let image = UIImage(data: data) {
        bundleImage.image = image
        wordOrImage = .image(caption: caption, image: bundleImage)
      }
    }
    return wordOrImage
  }
}

/// Encapsulates the "English" side of a vocabulary association, which can be either just a word
/// or an image.
enum WordOrImage: LosslessStringConvertible, Equatable {
  case word(String)
  case image(caption: String, image: TextBundleImage)

  init?(_ description: String) {
    // TODO: No way to customize these parsing rules
    let inlines = MiniMarkdown
      .ParsingRules()
      .parse(ArraySlice(StringSlice(description)))
    precondition(inlines.count == 1)
    if let image = inlines[0] as? MiniMarkdown.Image {
      self = .image(
        caption: String(image.text),
        image: TextBundleImage(image: nil, key: String(image.url))
      )
    } else {
      self = .word(description)
    }
  }

  var description: String {
    switch self {
    case .word(let word):
      return word
    case .image(caption: let caption, image: let image):
      return "![\(caption)](\(image.key ?? ""))"
    }
  }

  var identifier: String {
    switch self {
    case .word(let word):
      return word
    case .image(caption: let caption, image: _):
      return caption
    }
  }

  var image: UIImage? {
    if case .image(_, let textBundleImage) = self, let image = textBundleImage.image {
      return image
    } else {
      return nil
    }
  }

  var word: String {
    switch self {
    case .word(let word):
      return word
    case .image(caption: let caption, image: _):
      return caption
    }
  }

  func attributedString(with font: UIFont) -> NSAttributedString {
    switch self {
    case .word(let word):
      return NSAttributedString(string: word, attributes: [.font: font])
    case .image(caption: let caption, image: let image):
      let results = NSMutableAttributedString()
      if let image = image.image {
        let attachment = NSTextAttachment()
        attachment.image = image
        let aspectRatio = image.size.width / image.size.height
        attachment.bounds = CGRect(x: 0, y: 0, width: 100.0 * aspectRatio, height: 100.0)
        results.append(NSAttributedString(attachment: attachment))
      }
      if !caption.isEmpty {
        results.append(NSAttributedString(string: "\n", attributes: [.font: font]))
        results.append(NSAttributedString(string: caption, attributes: [.font: font]))
      }
      return results
    }
  }
}

/// An image inside the TextBundleDocument.
struct TextBundleImage: Equatable {

  /// The decoded image data.
  var image: UIImage?

  /// The key for loading the data (e.g., "assets/1234.png")
  var key: String?
}

/// Converts a Markdown string to a String preserving only what is in "text" nodes.
private let textOnlyRenderer: MarkdownStringRenderer = {
  var renderer = MarkdownStringRenderer()
  renderer.renderFunctions[.text] = { return String($0.slice.substring) }
  return renderer
}()

/// Represents and association of a Spanish to an English word. This association generates
/// 2 or 3 cards, which are specific things to remember:
///
/// - Given the Spanish word, what is the English word?
/// - Given the Engish word, what is the Spanish word?
/// - How do you spell the Spanish word? (optional)
struct VocabularyAssociation: Equatable {

  /// The Spanish word.
  let spanish: String

  /// The associated English word. This can be either a word, just an image, or an image with a
  /// caption.
  var english: WordOrImage

  /// Whether or not to test spelling of this word.
  var testSpelling: Bool

  /// Constructs an association given just an English word.
  init(spanish: String, english: String, testSpelling: Bool = false) {
    self.spanish = spanish
    self.english = .word(english)
    self.testSpelling = testSpelling
  }

  /// Constructs an association given a full word-or-image for the English association.
  init(spanish: String, wordOrImage: WordOrImage, testSpelling: Bool = false) {
    self.spanish = spanish
    self.english = wordOrImage
    self.testSpelling = testSpelling
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
  static func makeAssociations(
    from markdown: String,
    document: TextBundleDocument
  ) -> ([VocabularyAssociation], Range<String.Index>) {
    // TODO: No way to customize these parsing rules
    let blocks = MiniMarkdown.ParsingRules().parse(markdown)
    return makeAssociations(from: blocks, document: document)
  }

  static func makeAssociations(
    from blocks: [Node],
    document: TextBundleDocument
  ) -> ([VocabularyAssociation], Range<String.Index>) {
    let maybeTable = blocks.first { $0.isTable(withColumnCount: 2) }
    guard let table = maybeTable as? MiniMarkdown.Table else {
      return ([], "".completeRange)
    }
    var cards: [VocabularyAssociation] = []
    for row in table.rows {
      guard let english = row.english(loadingImagesFrom: document) else { continue }
      cards.append(
        VocabularyAssociation(
          spanish: row.spanish,
          wordOrImage: english,
          testSpelling: row.testSpelling
        )
      )
    }
    return (cards, table.slice.range)
  }

  /// Creates cards from this association.
  var cards: [Card] {
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

  /// Returns the cards from all of the associations in the array.
  var cards: [Card] {
    return Array<Card>(self.map { $0.cards }.joined())
  }
}
