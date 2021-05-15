// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension StringProtocol where Self.SubSequence == Substring {
  typealias SubstringPair = (prefix: Substring, suffix: Substring)

  /// True if every unicode scalar in the string is either a whitespace or newline.
  var isWhitespace: Bool {
    return unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
  }

  func prefixAndSuffix(
    where predicate: (Character) -> Bool
  ) -> SubstringPair {
    let prefix = self.prefix(while: predicate)
    return (prefix: prefix, suffix: self[prefix.endIndex...])
  }

  func suffix(where predicate: (Character) -> Bool) -> Substring {
    guard startIndex != endIndex else { return self[startIndex ..< endIndex] }
    // TODO: what i *want* to do is just call prefix on the reversed string, but the type
    // checker complains about the indexes not matching. Figure out how to coerce Swift later.
    var index = self.index(before: endIndex)
    while index != startIndex, predicate(self[index]) {
      index = self.index(before: index)
    }
    index = self.index(after: index)
    return self[index...]
  }

  func suffixAndPrefix(
    where predicate: (Character) -> Bool
  ) -> SubstringPair {
    let suffix = self.suffix(where: predicate)
    return (prefix: self[startIndex ..< suffix.startIndex], suffix: suffix)
  }

  var leadingWhitespace: SubstringPair {
    return prefixAndSuffix(where: { $0.isWhitespace })
  }

  /// The substring of `self` that excludes any leading whitespace.
  var strippingLeadingWhitespace: Substring {
    return leadingWhitespace.suffix
  }

  /// The substring of `self` that excludes any leading and trailing whitespace
  var strippingLeadingAndTrailingWhitespace: Substring {
    return strippingLeadingWhitespace.suffixAndPrefix(where: { $0.isWhitespaceOrNewline }).prefix
  }

  /// True if the entire contents of the string is a valid table delimiter cell
  var isTableDelimiterCell: Bool {
    return range(of: "^\\s*:?-+:?\\s*$", options: .regularExpression) != nil
  }
}
