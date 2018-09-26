// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MiniMarkdown
import TextBundleKit

final class PlainTextDocument: UIDocument, EditableDocument {

  enum Error: Swift.Error {
    case internalInconsistency
    case couldNotOpenDocument
  }

  public var dataConnection: EditableDocumentDataConnection?

  /// Any internal error from working with the file.
  private(set) var previousError: Swift.Error?

  func didUpdateText() {
    updateChangeCount(.done)
  }

  override func contents(forType typeName: String) throws -> Any {
    let string = dataConnection?.editableDocumentCurrentText() ?? ""
    if let data = string.data(using: .utf8) {
      return data
    } else {
      throw Error.internalInconsistency
    }
  }

  override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard
      let data = contents as? Data,
      let string = String(data: data, encoding: .utf8)
      else {
        throw Error.internalInconsistency
    }
    dataConnection?.editableDocumentDidLoadText(string)
  }

  override func handleError(_ error: Swift.Error, userInteractionPermitted: Bool) {
    previousError = error
    finishedHandlingError(error, recovered: false)
  }
}

extension PlainTextDocument {

  struct Factory: DocumentFactory {
    var useCloud: Bool = true

    static let `default` = Factory()

    func openDocument(at url: URL, completion: @escaping (Result<PlainTextDocument>) -> Void) {
      let document = PlainTextDocument(fileURL: url)
      document.open { (success) in
        if success {
          completion(.success(document))
        } else {
          completion(.failure(document.previousError ?? Error.couldNotOpenDocument))
        }
      }
    }

    func merge(source: PlainTextDocument, destination: PlainTextDocument) { }

    func delete(_ document: PlainTextDocument) {
      document.close { (_) in
        try? FileManager.default.removeItem(at: document.fileURL)
      }
    }
  }
}
