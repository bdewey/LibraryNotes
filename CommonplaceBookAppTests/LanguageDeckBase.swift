// Copyright © 2018-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
import TextBundleKit
import XCTest

/// A test case base class that has an empty langaugeDeck available for each test case.
open class LanguageDeckBase: XCTestCase {
  /// The `LanguageDeck` to use for testing.
  var languageDeck: LanguageDeck!

  open override func setUp() {
    super.setUp()
    let pathComponent = UUID().uuidString + ".deck"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
    let document = TextBundleDocument(fileURL: temporaryURL)
    let didCreate = expectation(description: "did create")
    document.save(to: temporaryURL, for: .forCreating) { success in
      XCTAssert(success)
      didCreate.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    languageDeck = LanguageDeck(document: document)
    languageDeck.populateEmptyDocument()
  }

  open override func tearDown() {
    super.tearDown()
    languageDeck.document.close()
    try? FileManager.default.removeItem(at: languageDeck.document.fileURL)
  }
}
