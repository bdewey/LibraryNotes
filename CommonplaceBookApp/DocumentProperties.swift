// Copyright © 2018 Brian's Brain. All rights reserved.

import CwlSignal
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

public struct DocumentProperties: Equatable, Codable {
  public var fileMetadata: FileMetadata
  public let hashtags: [String]
  public let placeholder: Bool
  public let title: String

  public init(fileMetadata: FileMetadata, nodes: [Node]) {
    self.fileMetadata = fileMetadata
    self.hashtags = nodes.hashtags
    self.placeholder = nodes.isEmpty
    self.title = String(nodes.title.split(separator: "\n").first ?? "")
  }

  public static func loadProperties(
    from metadataWrapper: FileMetadataWrapper,
    in container: URL,
    parsingRules: ParsingRules,
    completion: @escaping (Result<DocumentProperties>) -> Void
  ) {
    guard let document = metadataWrapper.value.editableDocument(in: container) else {
      completion(.failure(Error.noEditableDocument))
      return
    }
    document.open { (success) in
      if success {
        let textResult = document.currentTextResult
        document.close(completionHandler: nil)
        DispatchQueue.global(qos: .default).async {
          let result = textResult.flatMap({ (taggedText) -> DocumentProperties in
            let nodes = parsingRules.parse(taggedText.value)
            return DocumentProperties(
              fileMetadata: metadataWrapper.value,
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

extension DocumentProperties {
  enum Error: Swift.Error {
    case noEditableDocument
    case cannotOpenDocument
  }
}

extension DocumentProperties: CustomStringConvertible {
  public var description: String {
    return "\(title) \(fileMetadata)"
  }
}

public final class DocumentPropertiesListDiffable: ListDiffable {
  public private(set) var value: DocumentProperties

  public init(_ value: DocumentProperties) {
    self.value = value
  }

  public init(_ value: FileMetadata) {
    self.value = DocumentProperties(fileMetadata: value, nodes: [])
  }

  public func updateMetadata(_ metadata: FileMetadata) {
    value.fileMetadata = metadata
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return value.fileMetadata.fileName as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? DocumentPropertiesListDiffable else { return false }
    return value == otherWrapper.value
  }
}

extension DocumentPropertiesListDiffable: CustomStringConvertible, CustomDebugStringConvertible {
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
