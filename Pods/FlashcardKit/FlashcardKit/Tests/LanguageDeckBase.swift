// Copyright © 2018 Brian's Brain. All rights reserved.

import FlashcardKit
import TextBundleKit
import XCTest

/// A test case base class that has an empty langaugeDeck available for each test case.
open class LanguageDeckBase: XCTestCase {

  /// The `LanguageDeck` to use for testing.
  var languageDeck: LanguageDeck!

  override open func setUp() {
    super.setUp()
    let pathComponent = UUID().uuidString + ".deck"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
    let document = TextBundleDocument(fileURL: temporaryURL)
    let didCreate = expectation(description: "did create")
    document.save(to: temporaryURL, for: .forCreating) { (success) in
      XCTAssert(success)
      didCreate.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    languageDeck = LanguageDeck(document: document)
    languageDeck.populateEmptyDocument()
  }

  override open func tearDown() {
    super.tearDown()
    languageDeck.document.close()
    try? FileManager.default.removeItem(at: languageDeck.document.fileURL)
  }
}
