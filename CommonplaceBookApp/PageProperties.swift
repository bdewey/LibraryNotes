// Copyright © 2018 Brian's Brain. All rights reserved.

import CwlSignal
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

/// Metadata about pages in a Notebook.
public struct PageProperties: Codable {
  public var fileMetadata: FileMetadata
  public let hashtags: [String]
  public let title: String
  public let cardTemplates: [CardTemplateSerializationWrapper]

  public init(fileMetadata: FileMetadata, nodes: [Node]) {
    self.fileMetadata = fileMetadata
    self.hashtags = nodes.hashtags
    self.title = String(nodes.title.split(separator: "\n").first ?? "")
    self.cardTemplates = nodes.cardTemplates
  }

  public func updatingFileMetadata(_ fileMetadata: FileMetadata) -> PageProperties {
    var copy = self
    copy.fileMetadata = fileMetadata
    return copy
  }

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
    document.open { (success) in
      if success {
        let textResult = document.currentTextResult
        document.close()
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
}

extension PageProperties {
  enum Error: Swift.Error {
    case noEditableDocument
    case cannotOpenDocument
  }
}

extension PageProperties: CustomStringConvertible {
  public var description: String {
    return "\(title) \(fileMetadata)"
  }
}

extension Array where Element == Node {
  var cardTemplates: [CardTemplateSerializationWrapper] {
    var results = [CardTemplateSerializationWrapper]()
    results.append(
      contentsOf: VocabularyAssociation.makeAssociations(from: self).0
        .map { CardTemplateSerializationWrapper($0) }
    )
    results.append(
      contentsOf: ClozeTemplate.extract(from: self).map { CardTemplateSerializationWrapper($0) }
    )
    return results
  }
}

public final class PagePropertiesListDiffable: ListDiffable {
  public private(set) var value: PageProperties
  public private(set) var cardCount: Int

  public init(_ value: PageProperties, cardCount: Int) {
    self.value = value
    self.cardCount = cardCount
  }

  public func updateMetadata(_ metadata: FileMetadata) {
    value.fileMetadata = metadata
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

extension PagePropertiesListDiffable: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { return value.description }
  public var debugDescription: String {
    return "DocumentPropertiesListDiffable \(Unmanaged.passUnretained(self).toOpaque()) " + value.description
  }
}

/// Helpers for extracting document properties from nodes.
extension Array where Element == Node {
  var title: String {
    if let heading = self.lazy.compactMap({ $0.first(where: { $0.type == .heading }) }).first {
      return MarkdownStringRenderer.textOnly.render(node: heading)
    } else if let notBlank = self.lazy.compactMap({
      $0.first(where: { $0.type != .blank })
    }).first {
      return MarkdownStringRenderer.textOnly.render(node: notBlank)
    } else {
      return ""
    }
  }

  var hashtags: [String] {
    let hashtagSet = self
      .map { $0.findNodes(where: { $0.type == .hashtag }) }
      .joined()
      .reduce(into: Set<String>()) { $0.insert(String($1.slice.substring)) }
    return [String](hashtagSet)
  }
}
