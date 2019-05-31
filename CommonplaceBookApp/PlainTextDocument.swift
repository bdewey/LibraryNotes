// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

import CwlSignal
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

final class PlainTextDocument: UIDocumentWithPreviousError {
  enum Error: Swift.Error {
    case internalInconsistency
    case couldNotOpenDocument
  }

  override init(fileURL url: URL) {
    let (input, signal) = Signal<Tagged<String>>.create()
    textSignalInput = input
    textSignal = signal.continuous()
    super.init(fileURL: url)
  }

  private let textSignalInput: SignalInput<Tagged<String>>
  public let textSignal: Signal<Tagged<String>>
  private var text = ""

  func didUpdateText() {
    updateChangeCount(.done)
  }

  override func contents(forType typeName: String) throws -> Any {
    let string = text
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
    text = string
    textSignalInput.send(value: Tagged(tag: .document, value: text))
  }
}

extension PlainTextDocument: EditableDocument {
  var currentTextResult: Result<Tagged<String>> {
    // TODO: This isn't the real tag.
    return .success(Tagged(tag: .memory, value: text))
  }

  func applyTaggedModification(tag: Tag, modification: (String) -> String) {
    text = modification(text)
    updateChangeCount(.done)
    textSignalInput.send(value: Tagged(tag: tag, value: text))
  }

  func close() {
    close(completionHandler: nil)
  }
}
