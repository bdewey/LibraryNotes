// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit
import XCTest

private enum Identifiers {
  static let backButton = "Notes"
  static let currentCardView = "current-card"
  static let documentList = "document-list"
  static let editDocumentView = "edit-document-view"
  static let newDocumentButton = "new-document"
  static let skipBookDetailsButton = "book-details-skip-button"
  static let studyButton = "study-button"
  static let advanceTimeButton = "advance-time-button"
  static let bookHeaderTitle = "book-header-title"
  static let bookHeaderAuthor = "book-header-author"
  static let documentListActions = "document-list-actions"
}

private enum TestContent {
  static let singleCloze = """
  Cloze test
  #testing
  - This is a file with a ?[](cloze).
  """

  static func pickleText(title: String) -> String {
    let text = """
    \(title)
    #testing
    - Peter Piper picked a ?[unit of pickles](peck) of pickled peppers.
    """
    return text
  }

  static let doubleCloze = """
  Two cloze document
  #testing
  - Cards with a fill-in-the-blank -- is called a "?[](cloze)".
  The 45th President of **the United States** is ?[cheeto](Donald Trump).

  The question about Trump should be in an auto-continue list.
  """

  static let quote = """
  *Educated*, Tara Westover

  ## Quotes

  > It’s a tranquillity born of sheer immensity; it calms with its very magnitude, which renders the merely human of no consequence.
  > Ain’t nothin’ ?[](funnier) than real life, I tell you what. (34)
  """

  static let multipleClozeInOneTemplate = """
  Multiple clozes in one item
  - Peter Piper ?[did what?](picked) a ?[unit of pickles](peck) of pickled peppers.
  """
}

final class LibraryNotesAppUITests: XCTestCase {
  var application: XCUIApplication!

  override func setUp() {
    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    application = XCUIApplication()
    application.launchArguments.append("--uitesting")
    application.launch()

    XCUIDevice.shared.orientation = .portrait

    waitUntilElementExists(application.buttons[Identifiers.newDocumentButton])
  }

  var newDocumentButton: XCUIElement {
    let newDocumentButton = application.buttons[Identifiers.newDocumentButton]
    XCTAssertTrue(newDocumentButton.waitForExistence(timeout: 1))
    return newDocumentButton
  }

  var skipButton: XCUIElement {
    let skipButton = application.buttons[Identifiers.skipBookDetailsButton]
    XCTAssertTrue(skipButton.waitForExistence(timeout: 1))
    return skipButton
  }

  var documentListActionButton: XCUIElement {
    let button = application.buttons[Identifiers.documentListActions]
    XCTAssertTrue(button.waitForExistence(timeout: 1))
    return button
  }

  func testCanSkipBookDetailsAndMakeNote() {
    newDocumentButton.tap()
    skipButton.tap()
    XCTAssertTrue(application.textViews[Identifiers.editDocumentView].waitForExistence(timeout: 5))
  }

  func testCanCreateBookNote() {
    newDocumentButton.tap()

    let tablesQuery = application.tables
    let titleTextField = tablesQuery.textFields["Title"]
    XCTAssertTrue(titleTextField.waitForExistence(timeout: 5))
    titleTextField.tap()
    titleTextField.typeText("My Test Book")

    let authorTextField = tablesQuery/*@START_MENU_TOKEN@*/ .textFields["Author"]/*[[".cells[\"Author\"].textFields[\"Author\"]",".textFields[\"Author\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
    authorTextField.tap()
    authorTextField.typeText("Brian Dewey")
    application.navigationBars["Add Book"].buttons["Next"].tap()
    XCTAssertTrue(application.textViews[Identifiers.editDocumentView].waitForExistence(timeout: 5))
    XCTAssertTrue(application.staticTexts[Identifiers.bookHeaderTitle].waitForExistence(timeout: 2))
    XCTAssertEqual(application.staticTexts[Identifiers.bookHeaderTitle].label, "My Test Book")
    XCTAssertEqual(application.staticTexts[Identifiers.bookHeaderAuthor].label, "Brian Dewey")
  }

  func testNewDocumentCanBeEdited() {
    createDocument(with: "Test Document")
    waitUntilElementExists(application.staticTexts["Test Document"])
  }

  func testStudyButtonEnabledAfterCreatingClozeContent() {
    createDocument(with: TestContent.singleCloze)
    documentListActionButton.tap()
    XCTAssertTrue(application.buttons["Advance Time"].waitForExistence(timeout: 1))
    application.buttons["Advance Time"].tap()
    documentListActionButton.tap()
    waitUntilElementEnabled(application.buttons["Review (1)"])
  }
}

// Helpers
extension LibraryNotesAppUITests {
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

  private func waitUntilElementDisabled(
    _ element: XCUIElement,
    file: String = #file,
    line: Int = #line
  ) {
    wait(
      for: NSPredicate(format: "isEnabled == false"),
      evaluatedWith: element,
      message: "\(element) did not become disabled",
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
    waitForExpectations(timeout: 5) { error in
      XCTAssertNil(error)
    }
  }

  private func createDocument(with text: String) {
    newDocumentButton.tap()
    skipButton.tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    waitUntilElementExists(editView)
    editView.typeText(text)
    application.buttons["My Books"].tap()
  }

  private func createDocument(with text: [String]) {
    newDocumentButton.tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    waitUntilElementExists(editView)
    for line in text {
      editView.typeText(line)
    }
    application.buttons["My Books"].tap()
  }

  private func study(expectedCards: Int, noCardsLeft: Bool = true) {
    let studyButton = tapButton(identifier: Identifiers.studyButton)
    let currentCard = application.otherElements[Identifiers.currentCardView]
    for _ in 0 ..< expectedCards {
      waitUntilElementExists(currentCard)
      currentCard.tap()
      currentCard.swipeRight()
    }
    if noCardsLeft {
      // After going through all clozes we should automatically go back to the document list.
      waitUntilElementExists(studyButton)
      wait(
        for: NSPredicate(format: "isEnabled == false"),
        evaluatedWith: studyButton,
        message: "Studying should be disabled"
      )
    }
  }

  @discardableResult
  private func tapButton(identifier: String) -> XCUIElement {
    let button = application.buttons[identifier]
    waitUntilElementEnabled(button)
    button.tap()
    return button
  }
}
