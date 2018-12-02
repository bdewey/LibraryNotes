// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import MiniMarkdown
import TextBundleKit
import UIKit

/// UIDocument that stores the extracted properties of a Notebook.
/// Its intended lifetime is that of the notebook.
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

/// Protocol for communicating between the properties document and its owning Notebook.
public protocol DocumentPropertiesIndexDocumentDelegate: class {

  /// Sent when properties were loaded from disk.
  ///
  /// - parameter document: The document that loaded
  /// - parameter properties: The properties that were loaded.
  func indexDocument(
    _ document: DocumentPropertiesIndexDocument,
    didLoadProperties properties: [DocumentProperties]
  )

  /// Called when we need to save the document to disk.
  ///
  /// - returns: The properties that need to be saved.
  func indexDocumentPropertiesToSave(
    _ document: DocumentPropertiesIndexDocument
  ) -> [DocumentProperties]
}

// TODO: Find a better name
public protocol DocumentPropertiesIndexProtocol: NotebookPageChangeListener {
  var delegate: DocumentPropertiesIndexDocumentDelegate? { get set }
}

extension DocumentPropertiesIndexDocument: DocumentPropertiesIndexProtocol { }
