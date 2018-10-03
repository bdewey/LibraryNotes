// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MiniMarkdown
import TextBundleKit

final class PlainTextDocument: UIDocumentWithPreviousError,
  NSTextStorageDelegate {

  enum Error: Swift.Error {
    case internalInconsistency
    case couldNotOpenDocument
  }

  private var temporaryStorage: String?
  private var markdownTextStorage: MiniMarkdownTextStorage?

  func didUpdateText() {
    updateChangeCount(.done)
  }

  override func contents(forType typeName: String) throws -> Any {
    let string = markdownTextStorage?.markdown ?? ""
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
    if let markdownTextStorage = markdownTextStorage {
      markdownTextStorage.markdown = string
    } else {
      temporaryStorage = string
    }
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    updateChangeCount(.done)
  }
}

extension PlainTextDocument: EditableDocument {
  func markdownTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) -> MiniMarkdownTextStorage {
    precondition(markdownTextStorage == nil)
    let storage = TextBundleDocument.makeTextStorage(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers,
      stylesheet: stylesheet
    )
    storage.delegate = self
    if let text = temporaryStorage {
      storage.markdown = text
      temporaryStorage = nil
    }
    markdownTextStorage = storage
    return storage
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
