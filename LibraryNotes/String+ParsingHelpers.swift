// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension String {
  func appendingNewlineIfNecessary() -> String {
    if last == "\n" {
      return self
    } else {
      return appending("\n")
    }
  }

  func string(at range: NSRange) -> String {
    String(self[Range(range, in: self)!])
  }

  func int(at range: NSRange) -> Int? {
    Int(string(at: range))
  }

  var completeRange: NSRange {
    NSRange(startIndex ..< endIndex, in: self)
  }

  func count(of character: Character) -> Int {
    reduce(0) { count, stringCharacter -> Int in
      if stringCharacter == character { return count + 1 }
      return count
    }
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
