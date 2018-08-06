// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Describes changes made to a String **after** they have been made.
// TODO: Can I generalize this?
public struct PostFactoStringChange {
  public let editedRange: NSRange
  public let changeInLength: Int
  public let insertedSubstring: Substring
  
  public func change(from string: String) -> RangeReplaceableChange<String.Index, Substring> {
    let nsRange = NSRange(
      location: editedRange.location,
      length: editedRange.length - changeInLength
    )
    return RangeReplaceableChange(
      range: Range(nsRange, in: string)!,
      newElements: insertedSubstring
    )
  }
}
