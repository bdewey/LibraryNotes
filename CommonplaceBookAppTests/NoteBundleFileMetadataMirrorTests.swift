// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import FlashcardKit
import MiniMarkdown
import TextBundleKit
import XCTest

// swiftlint:disable force_try

final class NoteBundleFileMetadataMirrorTests: XCTestCase {
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
    let tempDocument = try! TemporaryFile(creatingTempDirectoryForFilename: "test.notebundle")
    let document = NoteBundleDocument(
      fileURL: tempDocument.fileURL,
      parsingRules: parsingRules
    )
    let observer = NoteBundleDocumentBlockObserver()
    let didLoadAllProperties = expectation(description: "did load all properties")
    observer.didUpdatePages = { properties in
      print(properties)
      if properties.count == 4 { didLoadAllProperties.fulfill() }
    }
    document.addObserver(observer)
    let mirror = NoteBundleFileMetadataMirror(
      document: document,
      metadataProvider: metadataProvider,
      automaticallyRenameFiles: false
    )
    waitForExpectations(timeout: 3, handler: nil)
    let desiredBaseNameForPage = mirror.desiredBaseNameForPage
    XCTAssertEqual(desiredBaseNameForPage.count, 2)
    XCTAssertEqual(desiredBaseNameForPage["page1.txt"], "sample")
    XCTAssertNil(desiredBaseNameForPage["2018-12-16.txt"])

    let didUpdateProperties = expectation(description: "did update properties")
    didUpdateProperties.assertForOverFulfill = false
    observer.didUpdatePages = { _ in
      didUpdateProperties.fulfill()
    }
    try? mirror.performRenames(mirror.desiredBaseNameForPage)
    waitForExpectations(timeout: 3, handler: nil)

    // page1.txt got renamed to sample.txt, and properties should reflect that.
    XCTAssertNotNil(document.noteBundle.pageProperties["sample.txt"])
    XCTAssertNil(document.noteBundle.pageProperties["page1.txt"])
  }
}

private class NoteBundleDocumentBlockObserver: NoteBundleDocumentObserver {
  var didChangeToState: ((UIDocument.State) -> Void)?
  var didUpdatePages: (([String: PageProperties]) -> Void)?

  func noteBundleDocument(
    _ document: NoteBundleDocument,
    didChangeToState state: UIDocument.State
  ) {
    didChangeToState?(state)
  }

  func noteBundleDocumentDidUpdatePages(_ document: NoteBundleDocument) {
    didUpdatePages?(document.noteBundle.pageProperties)
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
