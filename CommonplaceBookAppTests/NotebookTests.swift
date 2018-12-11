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

  func testStudySession() {
    // Create two documents with identical contents. This will guarantee that we have collisions
    // in identifiers.
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "spanish1.txt",
      contents: textWithCards
    ))
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "spanish2.txt",
      contents: textWithCards
    ))
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .loadStudyMetadata()
      .monitorMetadataProvider()
    let studySession = notebook.studySession()
    // 6 cards per document times 2 documents == 12 cards
    XCTAssertEqual(studySession.count, 12)

    // make sure filtering works
    let singleDocumentSession = notebook.studySession { (properties) -> Bool in
      return properties.fileMetadata.fileName == "spanish1.txt"
    }
    XCTAssertEqual(singleDocumentSession.count, 6)
  }

  func testStudyingUpdatesMetadata() {
    // Create two documents with identical contents. This will guarantee that we have collisions
    // in identifiers.
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "spanish1.txt",
      contents: textWithCards
    ))
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "spanish2.txt",
      contents: textWithCards
    ))
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .loadStudyMetadata()
      .monitorMetadataProvider()
    var studySession = notebook.studySession()
    while studySession.currentCard != nil {
      studySession.recordAnswer(correct: true)
    }
    verifyStudyMetadataChanged(for: notebook) {
      notebook.updateStudySessionResults(studySession)
    }
    // Now there should be nothing to study
    XCTAssertEqual(notebook.studySession().count, 0)
    // We saved the new metadata.
    let fileLength = metadataProvider
      .fileContents[Notebook.Key.studyMetadata.rawValue]?.count
      ?? 0
    XCTAssert(fileLength > 0)
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
    let notebookListener = TestListener() { (notebook, key) in
      guard key == .notebookProperties else { return }
      print("Checking condition: \(notebook.pages.mapValues { $0.tag.rawValue })")
      if condition(notebook) {
        conditionSatisfied.fulfill()
      }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
    notebook.removeListener(notebookListener)
  }

  // TODO: Is there a way to combine the two "wait for" functions?
  private func waitForStudyMetadata(in notebook: Notebook, condition: @escaping (Notebook) -> Bool) {
    if condition(notebook) {
      print("Condition immediately passed: \(notebook.pages.mapValues { $0.tag.rawValue })")
      return
    }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener() { (notebook, key) in
      guard key == .studyMetadata else { return }
      print("Checking condition: \(notebook.pages.mapValues { $0.tag.rawValue })")
      if condition(notebook) {
        conditionSatisfied.fulfill()
      }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
    notebook.removeListener(notebookListener)
  }

  private func verifyStudyMetadataChanged(for notebook: Notebook, block: () -> Void) {
    var listenerBlockExecuted = false
    let notebookListener = TestListener() { (_, key) in
      guard key == .studyMetadata else { return }
      listenerBlockExecuted = true
    }
    notebook.addListener(notebookListener)
    block()
    XCTAssert(listenerBlockExecuted, "Metadata listener should run")
    notebook.removeListener(notebookListener)
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

final class TestListener: NotebookChangeListener {

  typealias NotebookNotificationBlock = (Notebook, Notebook.Key) -> Void

  init(
    block: @escaping NotebookNotificationBlock
  ) {
    self.block = block
  }

  let block: NotebookNotificationBlock

  func notebook(_ notebook: Notebook, didChange key: Notebook.Key) {
    block(notebook, key)
  }
}

private let textWithCards = """
# Vocabulary

| Spanish           | Engish |
| ----------------- | ------ |
| tenedor #spelling | fork   |
| hombre            | man    |

# Mastering the verb "to be"

In Spanish, there are two verbs "to be": *ser* and *estar*.

1. *Ser* is used to identify a person, an animal, a concept, a thing, or any noun.
2. *Estar* is used to show location.
3. *Ser*, with an adjective, describes the "norm" of a thing.
- La nieve ?[to be](es) blanca.
4. *Estar* with an adjective shows a "change" or "condition."
"""
