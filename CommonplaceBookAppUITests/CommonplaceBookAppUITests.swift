// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

private enum Identifiers {
  static let backButton = "Back"
  static let documentList = "document-list"
  static let editDocumentView = "edit-document-view"
  static let newDocumentButton = "new-document"
  static let studyButton = "study-button"
}

private enum TestContent {
  static let singleCloze = """
Cloze test

#testing

- This is a file with a ?[](cloze).
"""
}

final class CommonplaceBookAppUITests: XCTestCase {

  var application: XCUIApplication!

  override func setUp() {
    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    application = XCUIApplication()
    application.launchArguments.append("--uitesting")
    application.launch()
  }

  func testHasNewDocumentButton() {
    let newDocumentButton = application.buttons[Identifiers.newDocumentButton]
    XCTAssertTrue(newDocumentButton.exists)
  }

  func testNewDocumentButtonWorks() {
    let newDocumentButton = application.buttons[Identifiers.newDocumentButton]
    newDocumentButton.tap()
    waitUntilElementExists(application.textViews[Identifiers.editDocumentView])
  }

  func testNewDocumentCanBeEdited() {
    createDocument(with: "Test Document")
    waitUntilElementExists(application.staticTexts["Test Document"])
  }

  func testStudyButtonEnabledAfterCreatingClozeContent() {
    createDocument(with: TestContent.singleCloze)
    waitUntilElementEnabled(application.buttons[Identifiers.studyButton])
  }

  func testStudyButtonStartsDisabled() {
    let studyButton = application.buttons[Identifiers.studyButton]
    waitUntilElementExists(studyButton)
    XCTAssertFalse(studyButton.isEnabled)
  }

  func testTableHasSingleRowAfterClozeContent() {
    createDocument(with: TestContent.singleCloze)
    waitUntilElementEnabled(application.buttons[Identifiers.studyButton])
    let documentList = application.collectionViews[Identifiers.documentList]
    waitUntilElementExists(documentList)
    XCTAssertEqual(documentList.cells.count, 1)
  }
}

// Helpers
extension CommonplaceBookAppUITests {

  /// Waits for an element to exist in the hierarchy.
  /// - parameter element: The element to test for.
  /// - note: From http://masilotti.com/xctest-helpers/
  private func waitUntilElementExists(
    _ element: XCUIElement,
    file: String = #file,
    line: Int = #line
  ) {
    wait(
      for: NSPredicate(format: "exists == true"),
      evaluatedWith: element,
      message: "Failed to find \(element) after 5 seconds",
      file: file,
      line: line
    )
  }

  private func waitUntilElementEnabled(
    _ element: XCUIElement,
    file: String = #file,
    line: Int = #line
  ) {
    wait(
      for: NSPredicate(format: "isEnabled == true"),
      evaluatedWith: element,
      message: "\(element) did not become enabled",
      file: file,
      line: line
    )
  }

  private func wait(
    for predicate: NSPredicate,
    evaluatedWith object: Any,
    message: String,
    file: String = #file,
    line: Int = #line
  ) {
    expectation(for: predicate, evaluatedWith: object, handler: nil)
    waitForExpectations(timeout: 5) { (error) -> Void in
      if error != nil {
        self.recordFailure(
          withDescription: message,
          inFile: file,
          atLine: line,
          expected: true
        )
      }
    }
  }

  private func createDocument(with text: String) {
    application.buttons[Identifiers.newDocumentButton].tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    waitUntilElementExists(editView)
    editView.typeText(text)
    editView.buttons[Identifiers.backButton].tap()
  }
}
