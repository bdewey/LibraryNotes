// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

public struct StringChange {
  let rangeToReplace: NSRange
  let replacement: String
  let finalResult: String
}

extension String {
  
  public mutating func applyChange(_ change: StringChange) {
    let range = Range(change.rangeToReplace, in: self)!
    self.replaceSubrange(range, with: change.replacement)
    assert(self == change.finalResult)
  }
  
  public func applyingChange(_ change: StringChange) -> String {
    var copy = self
    copy.applyChange(change)
    return copy
  }
  
  public func inverse(of change: StringChange) -> StringChange {
    let range = Range(change.rangeToReplace, in: self)!
    let originalSubstring = self[range]
    return StringChange(
      rangeToReplace: NSRange(
        location: change.rangeToReplace.location,
        length: change.replacement.unicodeScalars.count
      ),
      replacement: String(originalSubstring),
      finalResult: self
    )
  }
}

extension StringChange: CustomStringConvertible {
  public var description: String {
    return "Replace \(rangeToReplace) with \"\(replacement)\""
  }
}
