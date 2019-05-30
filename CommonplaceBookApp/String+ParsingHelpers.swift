// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

public extension String {
  func appendingNewlineIfNecessary() -> String {
    if last == "\n" {
      return self
    } else {
      return self.appending("\n")
    }
  }

  func string(at range: NSRange) -> String {
    return String(self[Range(range, in: self)!])
  }

  func int(at range: NSRange) -> Int? {
    return Int(string(at: range))
  }

  var completeRange: NSRange {
    return NSRange(startIndex ..< endIndex, in: self)
  }

  func count(of character: Character) -> Int {
    return reduce(0, { (count, stringCharacter) -> Int in
      if stringCharacter == character { return count + 1 }
      return count
    })
  }
}

public extension StringProtocol {
  /// Returns the index that is *after* the `count` occurence of `character` in the receiver.
  func index(after count: Int, character: Character) -> String.Index? {
    var index = startIndex
    var newlineCount = 0
    while index != endIndex {
      if self[index] == character { newlineCount += 1 }
      index = self.index(after: index)
      if newlineCount == count {
        return index
      }
    }
    return nil
  }
}
