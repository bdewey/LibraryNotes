// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

extension StringProtocol {
  /// True if `pattern` is contained in the receiver, with any number of intervening characters.
  /// - note: The algorithm does case-insensive comparisons of  characters.
  /// - note: If the pattern is empty, the method returns `true`
  func fuzzyMatch<S: StringProtocol>(pattern: S) -> Bool {
    var searchRange = startIndex ..< endIndex
    var patternIndex = pattern.startIndex
    while patternIndex != pattern.endIndex {
      if let resultRange = self.range(of: pattern[patternIndex ... patternIndex], options: .caseInsensitive, range: searchRange) {
        searchRange = index(after: resultRange.lowerBound) ..< endIndex
      } else {
        return false
      }
      patternIndex = pattern.index(after: patternIndex)
    }
    return true
  }
}
