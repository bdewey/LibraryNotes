// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import MiniMarkdown
import XCTest

final class NotebookTests: XCTestCase {
  let metadataProvider = TestMetadataProvider(
    fileInfo: [
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#hashtag #test1"),
      TestMetadataProvider.FileInfo(fileName: "page2.txt", contents: "#hashtag #test2"),
      ]
  )

  func testSimpleNotebook() {
    let propertiesDocument = TestPropertiesDocument()
    let notebook = Notebook(
      parsingRules: ParsingRules(),
      propertiesDocument: propertiesDocument,
      metadataProvider: metadataProvider
    )
    XCTAssert(notebook === propertiesDocument.delegate)
    XCTAssertEqual(notebook.pages.count, 2)
  }

  func testNotebookExtractsProperties() {
    let propertiesDocument = TestPropertiesDocument()
    let notebook = Notebook(
      parsingRules: ParsingRules(),
      propertiesDocument: propertiesDocument,
      metadataProvider: metadataProvider
    )
    XCTAssert(notebook === propertiesDocument.delegate)
    XCTAssertEqual(notebook.pages.count, 2)
    let didGetNotified = expectation(description: "did get notified")

    // When we don't have persisted properties, we read and update each file in a serial
    // background queue. Thus, two notifications before we know we know we have the hashtags
    var expectedNotifications = 2
    let notebookListener = TestListener {
      expectedNotifications -= 1
      if expectedNotifications == 0 { didGetNotified.fulfill() }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
    let page1Properties = notebook.pages["page1.txt"]!
    XCTAssertEqual(page1Properties.hashtags, ["#hashtag", "#test1"])
  }
}

final class TestListener: NotebookPageChangeListener {

  init(block: @escaping () -> Void) { self.block = block }

  let block: () -> Void

  func notebookPagesDidChange(_ index: Notebook) {
    block()
  }
}

final class TestPropertiesDocument: DocumentPropertiesIndexProtocol {
  var changeCount = 0

  weak var delegate: DocumentPropertiesIndexDocumentDelegate?

  func notebookPagesDidChange(_ index: Notebook) {
    changeCount += 1
  }
}
