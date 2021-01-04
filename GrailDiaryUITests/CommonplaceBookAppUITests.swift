// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit
import XCTest

private enum Identifiers {
  static let backButton = "All Notes"
  static let currentCardView = "current-card"
  static let documentList = "document-list"
  static let editDocumentView = "edit-document-view"
  static let newDocumentButton = "new-document"
  static let studyButton = "study-button"
  static let advanceTimeButton = "advance-time-button"
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

final class CommonplaceBookAppUITests: XCTestCase {
  var application: XCUIApplication!

  override func setUp() {
    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    application = XCUIApplication()
    application.launchArguments.append("--uitesting")
    application.launch()

    XCUIDevice.shared.orientation = .portrait
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
    tapButton(identifier: Identifiers.advanceTimeButton)
    waitUntilElementEnabled(application.buttons[Identifiers.studyButton])
  }

  func testStudyButtonStartsDisabled() {
    let studyButton = application.buttons[Identifiers.studyButton]
    waitUntilElementExists(studyButton)
    XCTAssertFalse(studyButton.isEnabled)
  }

  func testTableHasSingleRowAfterClozeContent() {
    createDocument(with: TestContent.singleCloze)
    let studyButton = application.buttons[Identifiers.studyButton]
    waitUntilElementExists(studyButton)
    XCTAssertFalse(studyButton.isEnabled)
    tapButton(identifier: Identifiers.advanceTimeButton)
    waitUntilElementEnabled(application.buttons[Identifiers.studyButton])
    let documentList = application.tables[Identifiers.documentList]
    waitUntilElementExists(documentList)
    XCTAssertEqual(documentList.cells.count, 1)
  }

  func testCreateMultipleFiles() {
    let numberOfFiles = 5
    for i in 1 ... numberOfFiles {
      createDocument(with: TestContent.pickleText(title: "Document \(i)"))
    }
    let finalTitle = "Document \(numberOfFiles)"
    let finalTitleLabel = application.staticTexts[finalTitle]
    waitUntilElementExists(finalTitleLabel)
    wait(
      for: NSPredicate(format: "cells.count == \(numberOfFiles)"),
      evaluatedWith: application.tables[Identifiers.documentList],
      message: "Expected \(numberOfFiles) rows"
    )
  }

  func testStudyFromASingleDocument() {
    createDocument(with: TestContent.doubleCloze)
    tapButton(identifier: Identifiers.advanceTimeButton)
    study(expectedCards: 2)
  }

  func testMultipleChallengesFromOneTemplateAreSuppressed() {
    createDocument(with: TestContent.multipleClozeInOneTemplate)
    tapButton(identifier: Identifiers.advanceTimeButton)
    study(expectedCards: 1)
  }

  func testStudyQuotes() {
    createDocument(with: TestContent.quote)
    tapButton(identifier: Identifiers.advanceTimeButton)
    study(expectedCards: 3)
  }

  func testRotation() {
    createDocument(with: TestContent.doubleCloze)
    let tableView = application.tables[Identifiers.documentList]
    let cell = tableView.cells["Two cloze document"]
    waitUntilElementExists(cell)
    let expectedWidthAfterRotation = tableView.frame.height
    XCTAssertEqual(tableView.frame.width, cell.frame.width)
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(tableView.exists)
    waitUntilElementExists(cell)
    XCTAssertEqual(tableView.frame.width, cell.frame.width)
    XCTAssertEqual(expectedWidthAfterRotation, cell.frame.width)
  }

  func testLimitStudySessionToTwenty() {
    var lines = [String]()
    lines.append("The Shining\n* ")
    for i in 0 ..< 25 {
      lines.append("All work and no play makes ?[who?](Jack) a dull boy. \(i)\n")
    }
    createDocument(with: lines)
    tapButton(identifier: Identifiers.advanceTimeButton)
    waitUntilElementExists(application.buttons["Review (25)"])
    study(expectedCards: 20, noCardsLeft: false)
    waitUntilElementExists(application.buttons["Review (5)"])
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
    let newDocumentButton = application.buttons[Identifiers.newDocumentButton]
    waitUntilElementExists(newDocumentButton)
    newDocumentButton.tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    waitUntilElementExists(editView)
    editView.typeText(text)
    application.buttons[Identifiers.backButton].tap()
  }

  private func createDocument(with text: [String]) {
    application.buttons[Identifiers.newDocumentButton].tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    waitUntilElementExists(editView)
    for line in text {
      editView.typeText(line)
    }
    application.buttons[Identifiers.backButton].tap()
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
