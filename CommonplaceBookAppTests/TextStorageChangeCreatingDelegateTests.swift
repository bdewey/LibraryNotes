// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import CommonplaceBookApp

final class TextStorageChangeCreatingDelegateTests: XCTestCase {

  var text = ""
  var textStorage: NSTextStorage!
  var delegate: TextStorageChangeCreatingDelegate!
  var changes: [EditableDocument.StringChange] = []
  var inverseChanges: [EditableDocument.StringChange] = []
  
  override func setUp() {
    super.setUp()
    changes = []
    textStorage = NSTextStorage()
    delegate = TextStorageChangeCreatingDelegate(changeBlock: { [weak self](postFactoChange) in
      guard let text = self?.text else { return }
      let change = postFactoChange.change(from: text)
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
  
  func testDeleteAtEnd() {
    setInitialText("Initial textx")
    textStorage.replaceCharacters(in: NSRange(location: 12, length: 1), with: "")
    XCTAssertEqual(text, "Initial text")
    XCTAssertEqual(undoingChanges(count: 1), "Initial textx")
  }

  fileprivate func setInitialText(_ text: String) {
    precondition(textStorage.length == 0)
    self.text = text
    delegate.suppressChangeBlock {
      textStorage.append(NSAttributedString(string: text))
    }
    XCTAssertEqual(changes.count, 0)
  }
  
  fileprivate func applyChange(_ change: EditableDocument.StringChange) {
    changes.append(change)
    let inverse = text.applyChange(change)
    inverseChanges.append(inverse)
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
