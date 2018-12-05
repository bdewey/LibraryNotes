// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import MiniMarkdown
import TextBundleKit
import XCTest

final class NotebookTests: XCTestCase {
  var metadataProvider: TestMetadataProvider!

  override func setUp() {
    metadataProvider = TestMetadataProvider(
      fileInfo: [
        TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#hashtag #test1"),
        TestMetadataProvider.FileInfo(fileName: "page2.txt", contents: "#hashtag #test2"),
        ]
    )
  }

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

  func testNotebookHasJSONImmediately() {
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
    XCTAssert(metadataProvider.delegate === notebook)
    wait(for: allPagesAreTruth, in: notebook)
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#newhashtag")
    )
    XCTAssertEqual(notebook.pages["page1.txt"]?.tag.rawValue, Tag.placeholder.rawValue)
    wait(for: allPagesAreTruth, in: notebook)
    XCTAssertEqual(notebook.pages["page1.txt"]!.value.hashtags, ["#newhashtag"])
  }

  // MARK: - Helpers

  private let allPagesAreTruth = NotebookTests.notebookPagesAllHaveTag(.truth)

  private let allPagesAreCached = NotebookTests.notebookPagesAllHaveTag(.fromCache)

  private static func notebookPagesAllHaveTag(_ tag: Tag) -> (Notebook) -> Bool {
    return { (notebook) in
      return notebook.pages.allSatisfy( { $1.tag == tag })
    }
  }

  private func wait(for condition: @escaping (Notebook) -> Bool, in notebook: Notebook) {
    if condition(notebook) { return }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener { (notebook) in
      if condition(notebook) {
        conditionSatisfied.fulfill()
      }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
  }
}

final class TestListener: NotebookPageChangeListener {

  init(block: @escaping (Notebook) -> Void) { self.block = block }

  let block: (Notebook) -> Void

  func notebookPagesDidChange(_ notebook: Notebook) {
    block(notebook)
  }
}
