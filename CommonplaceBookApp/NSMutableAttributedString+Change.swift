// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

extension NSMutableAttributedString {
  
  public struct Change {
    let range: NSRange
    let newString: NSAttributedString
  }
  
  public func applyChange(_ change: Change) {
    replaceCharacters(in: change.range, with: change.newString)
  }
  
  public func applyChange<C: Collection>(_ change: RangeReplaceableChange<C>) where C.Element == Character {
    self.replaceCharacters(in: change.range, with: String(change.newElements))
  }
  
  public func applyChanges<C: Collection>(_ changes: C) where C.Element == Change {
    for change in changes.sorted(by: { $1.range.location < $0.range.location }) {
      applyChange(change)
    }
  }
}
