// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public final class TextStorageChangeCreatingDelegate: NSObject, NSTextStorageDelegate {
  
  public typealias PostFactoStringChange = RangeReplaceableChange<Substring>
  
  private var suppressChange: Int = 0
  private let changeBlock: (PostFactoStringChange) -> Void
  
  public init(changeBlock: @escaping (PostFactoStringChange) -> Void) {
    self.changeBlock = changeBlock
  }
  
  public func suppressChangeBlock(during block: () -> ()) {
    suppressChange += 1
    block()
    suppressChange -= 1
  }
  
  public func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    guard suppressChange == 0, editedMask.contains(.editedCharacters) else { return }
    let originalRange = NSRange(location: editedRange.location, length: editedRange.length - delta)
    let insertedSubstring = textStorage.string[Range(editedRange, in: textStorage.string)!]
    let change = PostFactoStringChange(
      range: originalRange,
      newElements: insertedSubstring
    )
    changeBlock(change)
  }
}
