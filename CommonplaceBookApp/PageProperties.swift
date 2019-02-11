// Copyright © 2017-present Brian's Brain. All rights reserved.

import CwlSignal
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

/// Metadata about pages in a Notebook.
public struct PageProperties: Codable {
  /// FileMetadata identifying this page in a FileMetadatProvider.
  public var fileMetadata: FileMetadata

  /// Hashtags present in the page.
  public let hashtags: [String]

  /// Title of the page. May include Markdown formatting.
  public let title: String

  /// Parsing rules used when interpreting any formatting that may appear in `title`
  static var parsingRules = ParsingRules()

  /// Title with all markdown characters removed
  public var plainTextTitle: String {
    return PageProperties.parsingRules.parse(title).reduce(into: "") { string, node in
      string.append(MarkdownAttributedStringRenderer.textOnly.render(node: node).string)
    }
  }

  /// All card templates in the page.
  public let cardTemplates: [CardTemplateSerializationWrapper]

  /// Designated initializer.
  ///
  /// - parameter fileMetadata: FileMetadata identfying this page in a FileMetadataProvider.
  /// - parameter nodes: Parsed MiniMarkdown nodes from the content of the page.
  ///                    Relvant page properties are extracted from these nodes.
  public init(fileMetadata: FileMetadata, nodes: [Node]) {
    self.fileMetadata = fileMetadata
    self.hashtags = nodes.hashtags
    let title = String(nodes.title.split(separator: "\n").first ?? "")
    self.title = title
    self.cardTemplates = nodes.cardTemplates()
  }

  /// Returns a copy of the PageProperties with the file metadata changed.
  public func updatingFileMetadata(_ fileMetadata: FileMetadata) -> PageProperties {
    var copy = self
    copy.fileMetadata = fileMetadata
    return copy
  }

  public func renaming(to newName: String) -> PageProperties {
    var copy = self
    copy.fileMetadata.fileName = newName
    return copy
  }

  /// Loads PageProperties from an item in a FileMetadataProvider.
  ///
  /// - parameter metadataWrapper: The FileMetadata identifying the page.
  /// - parameter metadataProvider: The container of the page.
  /// - parameter parsingRules: Rules for parsing the contents of the page into nodes.
  /// - parameter completion: Routine called with the resulting properties.
  ///                         Called on the main thread.
  public static func loadProperties(
    from metadataWrapper: FileMetadata,
    in metadataProvider: FileMetadataProvider,
    parsingRules: ParsingRules,
    completion: @escaping (Result<PageProperties>) -> Void
  ) {
    guard let document = metadataProvider.editableDocument(for: metadataWrapper) else {
      completion(.failure(Error.noEditableDocument))
      return
    }
    document.open { success in
      if success {
        let textResult = document.currentTextResult
        document.close(completionHandler: nil)
        DispatchQueue.global(qos: .default).async {
          let result = textResult.flatMap({ (taggedText) -> PageProperties in
            let nodes = parsingRules.parse(taggedText.value)
            return PageProperties(
              fileMetadata: metadataWrapper,
              nodes: nodes
            )
          })
          DispatchQueue.main.async {
            completion(result)
          }
        }
      } else {
        let error = document.previousError ?? Error.cannotOpenDocument
        completion(.failure(error))
      }
    }
  }

  private static let commonWords: Set<String> = [
    "of",
    "the",
    "a",
    "an",
  ]

  private static let allowedNameCharacters: CharacterSet = {
    var allowedNameCharacters = CharacterSet.alphanumerics
    allowedNameCharacters.insert(" ")
    return allowedNameCharacters
  }()

  /// The "desired" base file name for this page.
  ///
  /// - note: The desired name comes from the first 5 words of the title, excluding
  ///         common words like "of", "a", "the", concatenated and separated by hyphens.
  public var desiredBaseFileName: String? {
    let sanitizedTitle = plainTextTitle
      .strippingLeadingAndTrailingWhitespace
      .filter {
        $0.unicodeScalars.count == 1
          && PageProperties.allowedNameCharacters.contains($0.unicodeScalars.first!)
      }
    guard !sanitizedTitle.isEmpty else { return nil }
    return sanitizedTitle
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace })
      .map { String($0) }
      .filter { !PageProperties.commonWords.contains($0) }
      .prefix(5)
      .joined(separator: "-")
  }

  /// Whether this page conforms to the desired base file name.
  public var hasDesiredBaseFileName: Bool {
    guard let name = desiredBaseFileName else { return true }
    return fileMetadata.fileName.hasPrefix(name)
  }
}

extension PageProperties {
  /// Kinds of errors when loading properties.
  enum Error: Swift.Error {
    /// Cannot get an EditableDocument for a specific FileMetadata.
    case noEditableDocument

    /// Cannot open an EditableDocument.
    case cannotOpenDocument
  }
}

extension PageProperties: CustomStringConvertible {
  /// For debugging: A string representation of the properties.
  // TODO: Consider making this a mirror instead.
  public var description: String {
    return "\(title) \(fileMetadata)"
  }
}

extension Array where Element == Node {
  /// For an array of Nodes, return all VocabularyAssociations and ClozeTemplates found in
  /// the nodes.
  // TODO: Make this extensible for other card template types.
  func cardTemplates() -> [CardTemplateSerializationWrapper] {
    var results = [CardTemplateSerializationWrapper]()
    results.append(
      contentsOf: VocabularyAssociation.makeAssociations(from: self).0
        .map { CardTemplateSerializationWrapper($0) }
    )
    results.append(
      contentsOf: ClozeTemplate.extract(from: self)
        .map { CardTemplateSerializationWrapper($0) }
    )
    results.append(
      contentsOf: QuoteTemplate.extract(from: self)
        .map { CardTemplateSerializationWrapper($0) }
    )
    return results
  }

  /// Extracts the title from an array of nodes.
  ///
  /// - note: If there is a heading anywhere in the nodes, the contents of the first heading
  ///         is the title. Otherwise, the contents of the first non-blank line is the title.
  var title: String {
    if let heading = self.lazy.compactMap(
      { $0.first(where: { $0.type == .heading }) }
    ).first as? Heading {
      return String(heading.inlineSlice.substring)
    } else if let notBlank = self.lazy.compactMap({
      $0.first(where: { $0.type != .blank })
    }).first {
      return notBlank.allMarkdown
    } else {
      return ""
    }
  }

  /// Extracts all hashtags from nodes.
  var hashtags: [String] {
    let hashtagSet = self
      .map { $0.findNodes(where: { $0.type == .hashtag }) }
      .joined()
      .reduce(into: Set<String>()) { $0.insert(String($1.slice.substring)) }
    return [String](hashtagSet)
  }
}

/// Wrapper around PageProperties for IGListKit.
public final class PagePropertiesListDiffable: ListDiffable {
  /// The wrapped PageProperties.
  public private(set) var value: PageProperties

  /// How many cards are eligible for study in this page.
  public private(set) var cardCount: Int

  /// Designated initializer.
  public init(_ value: PageProperties, cardCount: Int) {
    self.value = value
    self.cardCount = cardCount
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return value.fileMetadata.fileName as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? PagePropertiesListDiffable else { return false }
    return value.title == otherWrapper.value.title &&
      value.hashtags == otherWrapper.value.hashtags &&
      value.fileMetadata == otherWrapper.value.fileMetadata &&
      cardCount == otherWrapper.cardCount
  }
}

/// Debuggability extensions for PagePropertiesListDiffable.
extension PagePropertiesListDiffable: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { return value.description }
  public var debugDescription: String {
    return "DocumentPropertiesListDiffable \(Unmanaged.passUnretained(self).toOpaque()) "
      + value.description
  }
}
