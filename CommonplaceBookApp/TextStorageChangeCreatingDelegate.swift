// Copyright © 2018 Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

public final class TextStorageChangeCreatingDelegate: NSObject, NSTextStorageDelegate {

  public func miniMarkdownTextStorage(
    _ textStorage: MiniMarkdownTextStorage,
    willHighlightForEditsInRange range: NSRange
  ) {
    guard suppressChange == 0 else { return }
  }

  public typealias PostFactoStringChange = RangeReplaceableChange<Substring>

  private var suppressChange: Int = 0
  private let changeBlock: (PostFactoStringChange) -> Void

  public init(changeBlock: @escaping (PostFactoStringChange) -> Void) {
    self.changeBlock = changeBlock
  }

  public func suppressChangeBlock(during block: () -> Void) {
    suppressChange += 1
    block()
    suppressChange -= 1
  }

  public func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range _: NSRange,
    changeInLength delta: Int
  ) {
    guard suppressChange == 0, editedMask.contains(.editedCharacters) else { return }
    let range = editedRangeBeforeHighlighting(for: textStorage)
    let originalRange = NSRange(location: range.location, length: range.length - delta)
    let insertedSubstring = textStorage.string[Range(range, in: textStorage.string)!]
    let change = PostFactoStringChange(
      range: originalRange,
      newElements: insertedSubstring
    )
    changeBlock(change)
  }
}

private func editedRangeBeforeHighlighting(for textStorage: NSTextStorage) -> NSRange {
  if let miniMarkdownTextStorage = textStorage as? MiniMarkdownTextStorage,
     let range = miniMarkdownTextStorage.editedRangeBeforeHighlighting {
    return range
  }
  return textStorage.editedRange
}
