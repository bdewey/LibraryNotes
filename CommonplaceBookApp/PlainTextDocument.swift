// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MiniMarkdown

final class PlainTextDocument: UIDocument, EditableDocument {
  
  enum Error: Swift.Error {
    case internalInconsistency
    case couldNotOpenDocument
  }

  /// The document text.
  public var text: String {
    return normalizedText.normalizedCollection
  }
  
  public func applyChange(_ change: StringChange) {
    let inverse = normalizedText.applyChange(change)
    undoManager.registerUndo(withTarget: self) { (doc) in
      doc.normalizedText.applyChange(inverse)
    }
  }
  
  private var normalizedText = NormalizedCollection<String>()
  
  private let normalizer: StringNormalizer = {
    var normalizer = StringNormalizer()
    normalizer.nodeSubstitutions[.listItem] = { (node) in
      var changes: [RangeReplaceableChange<Substring>] = []
      if let firstWhitespaceIndex = node.slice.substring.firstIndex(where: { $0.isWhitespace }),
        node.slice.substring[firstWhitespaceIndex] != "\t" {
        let nsRange = NSRange(firstWhitespaceIndex ... firstWhitespaceIndex, in: node.slice.string)
        changes.append(RangeReplaceableChange(range: nsRange, newElements: "\t"))
      }
      return changes
    }
    return normalizer
  }()
  
  /// Any internal error from working with the file.
  private(set) var previousError: Swift.Error?
  
  override func contents(forType typeName: String) throws -> Any {
    if let data = normalizedText.originalCollection.data(using: .utf8) {
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
    let changes = Array(normalizer.normalizingChanges(for: string))
    normalizedText.setOriginalCollection(
      string,
      normalizingChanges: changes
    )
  }
  
  override func handleError(_ error: Swift.Error, userInteractionPermitted: Bool) {
    previousError = error
    finishedHandlingError(error, recovered: false)
  }
}

extension PlainTextDocument {
  
  struct Factory: DocumentFactory {
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
