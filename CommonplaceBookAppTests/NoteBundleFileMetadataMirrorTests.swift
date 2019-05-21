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
    metadataProvider.addPropertiesCache()
    let tempDocument = try! TemporaryFile(creatingTempDirectoryForFilename: "test.notebundle")
    let document = NoteBundleDocument(
      fileURL: tempDocument.fileURL,
      parsingRules: parsingRules
    )
    let observer = NoteBundleDocumentBlockObserver()
    let didLoadAllProperties = expectation(description: "did load all properties")
    observer.didUpdatePages = { properties in
      if properties.count == 4 { didLoadAllProperties.fulfill() }
    }
    document.addObserver(observer)
    let mirror = NoteBundleFileMetadataMirror(
      document: document,
      metadataProvider: metadataProvider
    )
    waitForExpectations(timeout: 3, handler: nil)
    let desiredBaseNameForPage = mirror.desiredBaseNameForPage
    XCTAssertEqual(desiredBaseNameForPage.count, 2)
    XCTAssertEqual(desiredBaseNameForPage["page1.txt"], "sample")
    XCTAssertNil(desiredBaseNameForPage["2018-12-16.txt"])
  }
}

private class NoteBundleDocumentBlockObserver: NoteBundleDocumentObserver {
  var didChangeToState: ((UIDocument.State) -> Void)?
  var didUpdatePages: (([String: NoteBundlePageProperties]) -> Void)?

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
