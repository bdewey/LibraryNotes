// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import CwlSignal
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result
import XCTest

final class NotebookTests: XCTestCase {
  func testSimpleNotebook() {
    let metadataProvider = TestMetadataProvider(
      container: URL(string: "test://metadata")!,
      fileMetadata: [
        FileMetadata(fileName: "page1.txt"),
        FileMetadata(fileName: "page2.txt"),
      ]
    )
    let propertiesDocument = TestPropertiesDocument()
    let notebook = Notebook(
      parsingRules: ParsingRules(),
      propertiesDocument: propertiesDocument,
      metadataProvider: metadataProvider
    )
    XCTAssert(notebook === propertiesDocument.delegate)
    XCTAssertEqual(notebook.pages.count, 2)
  }
}

struct TestMetadataProvider: FileMetadataProvider {
  init(container: URL, fileMetadata: [FileMetadata]) {
    self.container = container
    self.fileMetadata = fileMetadata
  }

  let container: URL
  let fileMetadata: [FileMetadata]
  weak var delegate: FileMetadataProviderDelegate?

  func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
    return TestEditableDocument("Hello, world!")
  }
}

final class TestPropertiesDocument: DocumentPropertiesIndexProtocol {
  var changeCount = 0

  weak var delegate: DocumentPropertiesIndexDocumentDelegate?

  func notebookPagesDidChange(_ index: Notebook) {
    changeCount += 1
  }
}

/// Test implementation of EditableDocument that keeps its values in memory.
final class TestEditableDocument: EditableDocument {

  /// Initialize with default text.
  init(_ text: String = "") {
    self.text = text
    let (input, signal) = Signal<Tagged<String>>.create()
    textSignalInput = input
    textSignal = signal.continuous()
  }

  var text: String
  var currentTextResult: Result<Tagged<String>> {
    return .success(Tagged(tag: .memory, value: text))
  }

  private let textSignalInput: SignalInput<Tagged<String>>
  var textSignal: Signal<Tagged<String>>

  func applyTaggedModification(tag: Tag, modification: (String) -> String) {
    text = modification(text)
    textSignalInput.send(value: Tagged(tag: .memory, value: text))
  }

  func open(completionHandler: ((Bool) -> Void)?) {
    completionHandler?(true)
  }

  func close() {
    // NOTHING
  }

  var previousError: Error?
}
