// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public final class TextStorageChangeCreatingDelegate: NSObject, NSTextStorageDelegate {
  
  private var suppressChange: Int = 0
  private let changeBlock: (StringChange) -> Void
  
  public init(changeBlock: @escaping (StringChange) -> Void) {
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
    let finalResult = textStorage.string
    let insertedSubstring = finalResult[Range(editedRange, in: finalResult)!]
    let change = StringChange(
      rangeToReplace: originalRange,
      replacement: String(insertedSubstring),
      finalResult: finalResult
    )
    changeBlock(change)
  }
}
