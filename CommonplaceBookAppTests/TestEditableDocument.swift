// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import CwlSignal
import Foundation
import TextBundleKit
import enum TextBundleKit.Result

protocol TestEditableDocumentDelegate: class {
  func document(_ document: TestEditableDocument, didUpdate text: String)
}

/// Test implementation of EditableDocument that keeps its values in memory.
final class TestEditableDocument: EditableDocument {

  /// Initialize with default text.
  init(name: String, text: String = "") {
    self.name = name
    self.text = text
    let (input, signal) = Signal<Tagged<String>>.create()
    textSignalInput = input
    textSignal = signal.continuous()
    textSignalInput.send(result: .success(Tagged(tag: .document, value: text)))
  }

  weak var delegate: TestEditableDocumentDelegate?

  let name: String

  /// The current text in the document.
  var text: String

  /// Current text, expressed as a "tagged result" (always "success", always "in memory")
  var currentTextResult: Result<Tagged<String>> {
    return .success(Tagged(tag: .memory, value: text))
  }

  /// Used to send changes to the text value.
  private let textSignalInput: SignalInput<Tagged<String>>

  /// Endpoint to subscribe to updates to the text value.
  var textSignal: Signal<Tagged<String>>

  /// Updates "text"
  func applyTaggedModification(tag: Tag, modification: (String) -> String) {
    text = modification(text)
    textSignalInput.send(value: Tagged(tag: tag, value: text))
    delegate?.document(self, didUpdate: text)
  }

  /// Stub function for opening a document.
  func open(completionHandler: ((Bool) -> Void)?) {
    completionHandler?(true)
  }

  /// Stub function for closing the document.
  func close() {
    // NOTHING
  }

  /// Stub for holding what the error would be when opening the document, if we could have errors.
  var previousError: Error?
}
