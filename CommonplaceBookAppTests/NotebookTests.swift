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

  let parsingRules = ParsingRules()

  func testNotebookExtractsProperties() {
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    )
    XCTAssertEqual(notebook.pages.count, 2)
    wait(for: allPagesAreTruth, in: notebook)
    XCTAssertEqual(Set(notebook.pages["page1.txt"]!.value.hashtags), Set(["#hashtag", "#test1"]))
    XCTAssertEqual(Set(notebook.pages["page2.txt"]!.value.hashtags), Set(["#hashtag", "#test2"]))
  }

  private let allPagesAreTruth: (Notebook) -> Bool = { (notebook) in
    return notebook.pages.allSatisfy({ (key, value) -> Bool in
      value.tag == .truth
    })
  }

  private let allPagesAreCached: (Notebook) -> Bool = { (notebook) in
    return notebook.pages.allSatisfy({ (key, value) -> Bool in
      value.tag == .fromCache
    })
  }

  private func wait(for condition: @escaping (Notebook) -> Bool, in notebook: Notebook) {
    if condition(notebook) { return }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener { (notebook) in
      if condition(notebook) { conditionSatisfied.fulfill() }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
  }

  func testNotebookHasJSONImmediately() {
    var metadataProvider = self.metadataProvider
    let cachedProperties = metadataProvider.documentPropertiesJSON
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(
        fileName: Notebook.cachedPropertiesName,
        contents: cachedProperties
      )
    )
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    )
    wait(for: allPagesAreCached, in: notebook)
    XCTAssertEqual(Set(notebook.pages["page1.txt"]!.value.hashtags), Set(["#hashtag", "#test1"]))
    XCTAssertEqual(Set(notebook.pages["page2.txt"]!.value.hashtags), Set(["#hashtag", "#test2"]))
  }

  func testModifyDocumentWillUpdateProperties() {
    XCTFail()
  }
}

final class TestListener: NotebookPageChangeListener {

  init(block: @escaping (Notebook) -> Void) { self.block = block }

  let block: (Notebook) -> Void

  func notebookPagesDidChange(_ notebook: Notebook) {
    block(notebook)
  }
}
