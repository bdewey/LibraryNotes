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
        TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "Sample #hashtag #test1"),
        TestMetadataProvider.FileInfo(fileName: "page2.txt", contents: "Sample #hashtag #test2"),
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
      return notebook.pageProperties.count == 2
        && notebook.pageProperties.allSatisfy { $1.tag == .truth }
    }
    XCTAssertEqual(
      Set(notebook.pageProperties["page1.txt"]!.value.hashtags),
      Set(["#hashtag", "#test1"])
    )
    XCTAssertEqual(
      Set(notebook.pageProperties["page2.txt"]!.value.hashtags),
      Set(["#hashtag", "#test2"])
    )
  }

  func testNotebookHasJSONImmediately() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties()
    waitForNotebook(notebook, condition: NotebookTests.allPagesAreCached)
    XCTAssertEqual(
      Set(notebook.pageProperties["page1.txt"]!.value.hashtags),
      Set(["#hashtag", "#test1"])
    )
    XCTAssertEqual(
      Set(notebook.pageProperties["page2.txt"]!.value.hashtags),
      Set(["#hashtag", "#test2"])
    )
  }

  func testModifyDocumentWillUpdateProperties() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties().monitorMetadataProvider()
    waitForNotebook(notebook, condition: NotebookTests.allPagesAreTruth)
    XCTAssert(metadataProvider.delegate === notebook)
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#newhashtag")
    )
    XCTAssertEqual(notebook.pageProperties["page1.txt"]?.tag.rawValue, Tag.placeholder.rawValue)
    waitForNotebook(notebook, condition: NotebookTests.allPagesAreTruth)
    XCTAssertEqual(notebook.pageProperties["page1.txt"]!.value.hashtags, ["#newhashtag"])
  }

  func testUpdatingPropertiesUpdatesCache() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(
      parsingRules: parsingRules,
      metadataProvider: metadataProvider
    ).loadCachedProperties().monitorMetadataProvider()
    waitForNotebook(notebook, condition: NotebookTests.allPagesAreTruth)
    XCTAssert(metadataProvider.delegate === notebook)
    startMonitoringForCacheSave()
    metadataProvider.addFileInfo(
      TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "#newhashtag")
    )
    waitForExpectations(timeout: 3, handler: nil)
    let deserializedPages = notebook.pagesDictionary(
      from: metadataProvider.fileContents[Notebook.Key.pageProperties.rawValue]!,
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
    waitForNotebook(notebook, condition: NotebookTests.noPagesArePlaceholders)
    XCTAssertEqual(notebook.pageProperties["cloze.txt"]?.value.cardTemplates.count, 1)
  }

  func testDeleteLiveNotebook() {
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .monitorMetadataProvider()
    waitForNotebook(notebook) { (notebook) -> Bool in
      return notebook.pageProperties.count == 2
        && notebook.pageProperties.allSatisfy { $1.tag == .truth }
    }
    XCTAssertEqual(notebook.pageProperties.count, 2)
    // thought: Maybe startMonitoring through to waitForExpecations should be in a method that
    // takes a block? expectCacheToSave(after: () -> Void)
    startMonitoringForCacheSave()
    notebook.deleteFileMetadata(notebook.pageProperties["page1.txt"]!.value.fileMetadata)
    XCTAssertEqual(notebook.pageProperties.count, 1)
    waitForExpectations(timeout: 3, handler: nil) // wait for cache save to happen
    let deserializedPages = notebook.pagesDictionary(
      from: metadataProvider.fileContents[Notebook.Key.pageProperties.rawValue]!,
      tag: .fromCache
    )
    XCTAssertEqual(deserializedPages.count, 1)
  }

  func testDeleteUnmonitoredNotebook() {
    // Create a properties.json that has info about page1.txt and page2.txt
    metadataProvider.addPropertiesCache()
    // Now get rid of page1.txt
    // swiftlint:disable:next force_try
    try! metadataProvider.delete(FileMetadata(fileName: "page1.txt"))
    // Load the notebook and wait for it to reconcile
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .monitorMetadataProvider()
    waitForNotebook(notebook, condition: NotebookTests.allPagesAreTruth)
    // there should be only one page.
    XCTAssertEqual(notebook.pageProperties.count, 1)
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

  func testCanRenamePage() {
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "spanish1.txt",
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
    verifyStudyMetadataChanged(for: notebook) {
       // swiftlint:disable:next force_try
      try! notebook.renamePage(from: "spanish1.txt", to: "spanish-new.txt")
    }
    XCTAssertNotNil(notebook.pageProperties["spanish-new.txt"])
    XCTAssertNotNil(metadataProvider.fileNameToMetadata["spanish-new.txt"])
    XCTAssertNil(metadataProvider.fileNameToMetadata["spanish1.txt"])
  }

  func testDetectDesiredRenames() {
    // Create one page where the file name matches the content.
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "my-sample-page.txt",
      contents: "# My sample page\n\nThis is my sample page!"
    ))
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: "2018-12-16.txt",
      contents: "#nocontent #onlyhashtags #notitle #anyfilenameworks"
    ))
    metadataProvider.addPropertiesCache()
    let notebook = Notebook(parsingRules: parsingRules, metadataProvider: metadataProvider)
      .loadCachedProperties()
      .loadStudyMetadata()
      .monitorMetadataProvider()
    let desiredBaseNameForPage = notebook.desiredBaseNameForPage
    XCTAssertEqual(desiredBaseNameForPage.count, 2)
    XCTAssertEqual(
      notebook.pageProperties["page1.txt"]?.value.desiredBaseFileName,
      "sample"
    )
    XCTAssertEqual(desiredBaseNameForPage["page1.txt"], "sample")
    XCTAssertNil(desiredBaseNameForPage["2018-12-16.txt"])
  }
}

/// Helpers.
extension NotebookTests {

  private static let allPagesAreTruth = NotebookTests.notebookPagesAllHaveTag(.truth)

  private static let allPagesAreCached = NotebookTests.notebookPagesAllHaveTag(.fromCache)

  private static let noPagesArePlaceholders = NotebookTests.notebookPagesNoneHaveTag(.placeholder)

  private static func notebookPagesAllHaveTag(_ tag: Tag) -> (Notebook) -> Bool {
    return { (notebook) in
      return notebook.pageProperties.allSatisfy({ $1.tag == tag })
    }
  }

  private static func notebookPagesNoneHaveTag(_ tag: Tag) -> (Notebook) -> Bool {
    return { (notebook) in
      return notebook.pageProperties.allSatisfy({ $1.tag != tag })
    }
  }

  private func waitForNotebook(_ notebook: Notebook, condition: @escaping (Notebook) -> Bool) {
    if condition(notebook) {
      print("Condition immediately passed: "
        + "\(notebook.pageProperties.mapValues { $0.tag.rawValue })")
      return
    }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener { (notebook, key) in
      guard key == .pageProperties else { return }
      print("Checking condition: \(notebook.pageProperties.mapValues { $0.tag.rawValue })")
      if condition(notebook) {
        conditionSatisfied.fulfill()
      }
    }
    notebook.addListener(notebookListener)
    waitForExpectations(timeout: 3, handler: nil)
    notebook.removeListener(notebookListener)
  }

  // TODO: Is there a way to combine the two "wait for" functions?
  private func waitForStudyMetadata(
    in notebook: Notebook,
    condition: @escaping (Notebook) -> Bool
  ) {
    if condition(notebook) {
      print("Condition immediately passed: "
        + "\(notebook.pageProperties.mapValues { $0.tag.rawValue })")
      return
    }
    let conditionSatisfied = expectation(description: "generic condition")
    let notebookListener = TestListener { (notebook, key) in
      guard key == .studyMetadata else { return }
      print("Checking condition: \(notebook.pageProperties.mapValues { $0.tag.rawValue })")
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
    let notebookListener = TestListener { (_, key) in
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
      if name == Notebook.Key.pageProperties.rawValue {
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
