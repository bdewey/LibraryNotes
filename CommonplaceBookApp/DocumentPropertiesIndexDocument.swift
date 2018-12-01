// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import MiniMarkdown
import TextBundleKit
import UIKit

public protocol DocumentPropertiesIndexDocumentDelegate: class {
  func indexDocument(
    _ document: DocumentPropertiesIndexDocument,
    didLoadProperties: [DocumentProperties]
  )

  func indexDocumentPropertiesToSave(
    _ document: DocumentPropertiesIndexDocument
  ) -> [DocumentProperties]
}

public final class DocumentPropertiesIndexDocument: UIDocumentWithPreviousError {
  enum Error: Swift.Error {
    case couldNotOpenDocument
  }

  public static let name = "properties.json"

  public init(
    fileURL url: URL,
    parsingRules: ParsingRules
  ) {
    self.parsingRules = parsingRules
    super.init(fileURL: url)
  }

  private let parsingRules: ParsingRules
  public weak var delegate: DocumentPropertiesIndexDocumentDelegate?

  public override func contents(forType typeName: String) throws -> Any {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.dateEncodingStrategy = .iso8601
    jsonEncoder.outputFormatting = .prettyPrinted
    let properties = delegate?.indexDocumentPropertiesToSave(self) ?? []
    return try jsonEncoder.encode(properties)
  }

  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard let data = contents as? Data else { return }
    let jsonDecoder = JSONDecoder()
    jsonDecoder.dateDecodingStrategy = .iso8601
    jsonDecoder.userInfo[.markdownParsingRules] = parsingRules
    do {
      let encodedProperties = try jsonDecoder.decode([DocumentProperties].self, from: data)
      delegate?.indexDocument(self, didLoadProperties: encodedProperties)
    } catch {
      DDLogError("Error loading properties index: \(error)")
      throw error
    }
  }
}

extension DocumentPropertiesIndexDocument: NotebookPageChangeListener {
  public func notebookPagesDidChange(_ index: Notebook) {
    updateChangeCount(.done)
  }
}

extension DocumentPropertiesIndexDocument {
  public struct Factory: DocumentFactory {
    public init(parsingRules: ParsingRules) {
      self.parsingRules = parsingRules
    }

    public let parsingRules: ParsingRules
    public let useCloud = true

    public func openDocument(
      at url: URL,
      completion: @escaping (Result<DocumentPropertiesIndexDocument>) -> Void
    ) {
      let document = DocumentPropertiesIndexDocument(fileURL: url, parsingRules: parsingRules)
      document.open { (success) in
        if success {
          completion(.success(document))
        } else {
          // Try creating the document
          document.save(to: url, for: .forCreating, completionHandler: { (createSuccess) in
            if createSuccess {
              completion(.success(document))
            } else {
              completion(.failure(document.previousError ?? Error.couldNotOpenDocument))
            }
          })
        }
      }
    }

    public func merge(
      source: DocumentPropertiesIndexDocument,
      destination: DocumentPropertiesIndexDocument
    ) {
      // NOTHING
    }

    public func delete(_ document: DocumentPropertiesIndexDocument) {
      document.close { (_) in
        try? FileManager.default.removeItem(at: document.fileURL)
      }
    }
  }
}
