// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

extension StringProtocol {
  /// True if `pattern` is contained in the receiver, with any number of intervening characters.
  /// - note: The algorithm does case-insensive comparisons of  characters.
  /// - note: If the pattern is empty, the method returns `true`
  func fuzzyMatch<S: StringProtocol>(pattern: S) -> Bool {
    var searchRange = startIndex ..< endIndex
    var patternIndex = pattern.startIndex
    while patternIndex != pattern.endIndex {
      if let resultRange = range(of: pattern[patternIndex ... patternIndex], options: .caseInsensitive, range: searchRange) {
        searchRange = index(after: resultRange.lowerBound) ..< endIndex
      } else {
        return false
      }
      patternIndex = pattern.index(after: patternIndex)
    }
    return true
  }
}
