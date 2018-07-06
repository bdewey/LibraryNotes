// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import CommonplaceBookApp

final class TextStorageChangeCreatingDelegateTests: XCTestCase {

  var text = ""
  var textStorage: NSTextStorage!
  var delegate: TextStorageChangeCreatingDelegate!
  var changes: [StringChange] = []
  var inverseChanges: [StringChange] = []
  
  override func setUp() {
    super.setUp()
    changes = []
    textStorage = NSTextStorage()
    delegate = TextStorageChangeCreatingDelegate(changeBlock: { [weak self](change) in
      self?.applyChange(change)
    })
    textStorage.delegate = delegate
  }

  func testSimpleInsertion() {
    setInitialText("Initial text")
    textStorage.insert(NSAttributedString(string: "awesome "), at: 8)
    XCTAssertEqual(text, "Initial awesome text")
  }
  
  func testReplaceText() {
    setInitialText("Initial text")
    textStorage.replaceCharacters(in: NSRange(location: 8, length: 4), with: "words")
    XCTAssertEqual(text, "Initial words")
    XCTAssertEqual(undoingChanges(count: 1), "Initial text")
  }

  fileprivate func setInitialText(_ text: String) {
    precondition(textStorage.length == 0)
    self.text = text
    delegate.suppressChangeBlock {
      textStorage.append(NSAttributedString(string: text))
    }
    XCTAssertEqual(changes.count, 0)
  }
  
  fileprivate func applyChange(_ change: StringChange) {
    changes.append(change)
    inverseChanges.append(text.inverse(of: change))
    text.applyChange(change)
  }
  
  fileprivate func undoingChanges(count: Int) -> String {
    precondition(count <= inverseChanges.count)
    var result = text
    var undoStack = inverseChanges
    for _ in 0 ..< count {
      result.applyChange(undoStack.popLast()!)
    }
    return result
  }
}
