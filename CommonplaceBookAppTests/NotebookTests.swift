// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import FlashcardKit
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
        ],
      parsingRules: parsingRules
    )
  }

  let parsingRules: ParsingRules = {
    var parsingRules = ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
    return parsingRules
  }()

  func testNotebookExtractsProperties() {
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties().monitorMetadataProvider()
    waitForNotebook(notebook) { (notebook) -> Bool in
      return notebook.pages.count == 2 && notebook.pages.allSatisfy { $1.tag == .truth }
    }
    XCTAssertEqual(Set(notebook.pages["page1.txt"]!.value.hashtags), Set(["#hashtag", "#test1"]))
    XCTAssertEqual(Set(notebook.pages["page2.txt"]!.value.hashtags), Set(["#hashtag", "#test2"]))
  }

  func testNotebookHasJSONImmediately() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties()
    waitForNotebook(notebook, condition: allPagesAreCached)
    XCTAssertEqual(Set(notebook.pages["page1.txt"]!.value.hashtags), Set(["#hashtag", "#test1"]))
    XCTAssertEqual(Set(notebook.pages["page2.txt"]!.value.hashtags), Set(["#hashtag", "#test2"]))
  }

  func testModifyDocumentWillUpdateProperties() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties().monitorMetadataProvider()
    waitForNotebook(notebook, condition: allPagesAreTruth)
    XCTAssert(metadataProvider.delegate === notebook)
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#newhashtag")
    )
    XCTAssertEqual(notebook.pages["page1.txt"]?.tag.rawValue, Tag.placeholder.rawValue)
    waitForNotebook(notebook, condition: allPagesAreTruth)
    XCTAssertEqual(notebook.pages["page1.txt"]!.value.hashtags, ["#newhashtag"])
  }

  func testUpdatingPropertiesUpdatesCache() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties().monitorMetadataProvider()
    waitForNotebook(notebook, condition: allPagesAreTruth)
    XCTAssert(metadataProvider.delegate === notebook)
    startMonitoringForCacheSave()
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#newhashtag")
    )
    waitForExpectations(timeout: 3, handler: nil)
    let deserializedPages = notebook.pagesDictionary(
      from: metadataProvider.fileContents[Notebook.cachedPropertiesName]!,
      tag: .fromCache
    )
    XCTAssertEqual(deserializedPages["page1.txt"]?.value.hashtags, ["#newhashtag"])
  }

  func testLoadPropertiesWithClozes() {
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "cloze.txt",
      contents: "- Here is text with a ?[cloze](thing that is removed) for you to study.\n"
    ))
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties()
    waitForNotebook(notebook, condition: noPagesArePlaceholders)
    XCTAssertEqual(notebook.pages["cloze.txt"]?.value.cardTemplates.count, 1)
  }

  func testDeleteLiveNotebook() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .monitorMetadataProvider()
    waitForNotebook(notebook) { (notebook) -> Bool in
      return notebook.pages.count == 2 && notebook.pages.allSatisfy { $1.tag == .truth }
    }
    XCTAssertEqual(notebook.pages.count, 2)
    // thought: Maybe startMonitoring through to waitForExpecations should be in a method that
    // takes a block? expectCacheToSave(after: () -> Void)
    startMonitoringForCacheSave()
    notebook.deleteFileMetadata(notebook.pages["page1.txt"]!.value.fileMetadata)
    XCTAssertEqual(notebook.pages.count, 1)
    waitForExpectations(timeout: 3, handler: nil) // wait for cache save to happen
    let deserializedPages = notebook.pagesDictionary(
      from: metadataProvider.fileContents[Notebook.cachedPropertiesName]!,
      tag: .fromCache
    )
    XCTAssertEqual(deserializedPages.count, 1)
  }

  func testDeleteUnmonitoredNotebook() {
    // Create a properties.json that has info about page1.txt and page2.txt
    metadataProvider.addPropertiesCache()
    // Now get rid of page1.txt
    try! metadataProvider.delete(FileMetadata(fileName: "page1.txt")) // swiftlint:disable:this force_try
    // Load the notebook and wait for it to reconcile
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .monitorMetadataProvider()
    waitForNotebook(notebook, condition: allPagesAreTruth)
    // there should be only one page.
    XCTAssertEqual(notebook.pages.count, 1)
  }

  // MARK: - Helpers

  private let allPagesAreTruth = NotebookTests.notebookPagesAllHaveTag(.truth)

  private let allPagesAreCached = NotebookTests.notebookPagesAllHaveTag(.fromCache)

  private let noPagesArePlaceholders = NotebookTests.notebookPagesNoneHaveTag(.placeholder)

  private static func notebookPagesAllHaveTag(_ tag: Tag) -> (Notebook) -> Bool {
    return { (notebook) in
      return notebook.pages.allSatisfy({ $1.tag == tag })
    }
  }

  private static func notebookPagesNoneHaveTag(_ tag: Tag) -> (Notebook) -> Bool {
    return { (notebook) in
      return notebook.pages.allSatisfy({ $1.tag != tag })
    }
  }

  private func waitForNotebook(_ notebook: Notebook, condition: @escaping (Notebook) -> Bool) {
    if condition(notebook) {
      print("Condition immediately passed: \(notebook.pages.mapValues { $0.tag.rawValue })")
      return
    }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener { (notebook) in
      print("Checking condition: \(notebook.pages.mapValues { $0.tag.rawValue })")
      if condition(notebook) {
        conditionSatisfied.fulfill()
      }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
  }

  private func startMonitoringForCacheSave() {
    let didSaveCache = expectation(description: "did save cache")
    metadataProvider.contentsChangeListener = { (name, text) in
      if name == Notebook.cachedPropertiesName {
        didSaveCache.fulfill()
      }
    }
  }
}

final class TestListener: NotebookPageChangeListener {

  init(block: @escaping (Notebook) -> Void) { self.block = block }

  let block: (Notebook) -> Void

  func notebookPagesDidChange(_ notebook: Notebook) {
    block(notebook)
  }
}
