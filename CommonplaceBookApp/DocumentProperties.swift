// Copyright © 2018 Brian's Brain. All rights reserved.

import CwlSignal
import Foundation
import IGListKit
import TextBundleKit
import enum TextBundleKit.Result

public struct DocumentProperties: Equatable, Codable {
  public let fileMetadata: FileMetadata
  public let title: String

  private init(fileMetadata: FileMetadata, text: String) {
    self.fileMetadata = fileMetadata
    self.title = String(text.split(separator: "\n").first ?? "")
  }

  public static func loadProperties(
    from metadataWrapper: FileMetadataWrapper,
    completion: @escaping (Result<DocumentProperties>) -> Void
  ) {
    guard let document = metadataWrapper.value.editableDocument else {
      completion(.failure(Error.noEditableDocument))
      return
    }
    document.open { (success) in
      if success {
        let textResult = document.currentTextResult
        DispatchQueue.global(qos: .default).async {
          let result = textResult.flatMap({ (taggedText) -> DocumentProperties in
            return DocumentProperties(
              fileMetadata: metadataWrapper.value,
              text: taggedText.value
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

public final class DocumentPropertiesListDiffable: ListDiffable {
  public let value: DocumentProperties

  public init(_ value: DocumentProperties) {
    self.value = value
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return value.fileMetadata.fileURL as NSURL
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? DocumentPropertiesListDiffable else { return false }
    return value == otherWrapper.value
  }
}
