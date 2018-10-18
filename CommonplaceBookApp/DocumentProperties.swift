// Copyright © 2018 Brian's Brain. All rights reserved.

import CwlSignal
import Foundation
import TextBundleKit
import enum TextBundleKit.Result

public struct DocumentProperties: Codable {
  public let contentChangeDate: Date
  public let title: String
  public let url: URL

  private init(contentChangeDate: Date, url: URL, text: String) {
    self.contentChangeDate = contentChangeDate
    self.url = url
    self.title = String(text.split(separator: "\n").first ?? "")
  }

  public static func loadProperties(
    from metadataWrapper: FileMetadataWrapper,
    completion: @escaping (Result<DocumentProperties>) -> Void
  ) {
    guard let document = metadataWrapper.editableDocument else {
      completion(.failure(Error.noEditableDocument))
      return
    }
    document.open { (success) in
      if success {
        let result = document.currentTextResult.flatMap({ (taggedText) -> DocumentProperties in
          return DocumentProperties(
            contentChangeDate: metadataWrapper.value.contentChangeDate,
            url: metadataWrapper.value.fileURL,
            text: taggedText.value
          )
        })
        completion(result)
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
