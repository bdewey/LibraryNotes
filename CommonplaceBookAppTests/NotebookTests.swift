// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import MiniMarkdown
import XCTest

final class NotebookTests: XCTestCase {
  func testSimpleNotebook() {
    let metadataProvider = TestMetadataProvider(
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

final class TestPropertiesDocument: DocumentPropertiesIndexProtocol {
  var changeCount = 0

  weak var delegate: DocumentPropertiesIndexDocumentDelegate?

  func notebookPagesDidChange(_ index: Notebook) {
    changeCount += 1
  }
}
