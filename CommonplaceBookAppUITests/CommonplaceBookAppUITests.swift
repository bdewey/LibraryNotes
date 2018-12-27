// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

private enum Identifiers {
  static let backButton = "Back"
  static let editDocumentView = "edit-document-view"
  static let newDocumentButton = "new-document"
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
    wait(for: application.textViews[Identifiers.editDocumentView])
  }

  func testNewDocumentCanBeEdited() {
    application.buttons[Identifiers.newDocumentButton].tap()
    let editView = application.textViews[Identifiers.editDocumentView]
    wait(for: editView)
    let text = "Test Document"
    editView.typeText(text)
    editView.buttons[Identifiers.backButton].tap()
    wait(for: application.staticTexts[text])
  }
}

// Helpers
extension CommonplaceBookAppUITests {

  /// Waits for an element to exist in the hierarchy.
  /// - parameter element: The element to test for.
  /// - note: From http://masilotti.com/xctest-helpers/
  private func wait(
    for element: XCUIElement,
    file: String = #file,
    line: Int = #line
  ) {
    expectation(
      for: NSPredicate(format: "exists == true"),
      evaluatedWith: element,
      handler: nil
    )

    waitForExpectations(timeout: 5) { (error) -> Void in
      if error != nil {
        let message = "Failed to find \(element) after 5 seconds."
        self.recordFailure(
          withDescription: message,
          inFile: file,
          atLine: line,
          expected: true
        )
      }
    }
  }
}
