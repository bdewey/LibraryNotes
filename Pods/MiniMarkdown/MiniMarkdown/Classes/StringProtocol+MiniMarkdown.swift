//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

public extension StringProtocol where Self.SubSequence == Substring {
  public typealias SubstringPair = (prefix: Substring, suffix: Substring)

  /// True if every unicode scalar in the string is either a whitespace or newline.
  public var isWhitespace: Bool {
    return unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
  }

  public func prefixAndSuffix(
    where predicate: (Character) -> Bool
  ) -> SubstringPair {
    let prefix = self.prefix(while: predicate)
    return (prefix: prefix, suffix: self[prefix.endIndex...])
  }

  public func suffix(where predicate: (Character) -> Bool) -> Substring {
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

  public func suffixAndPrefix(
    where predicate: (Character) -> Bool
  ) -> SubstringPair {
    let suffix = self.suffix(where: predicate)
    return (prefix: self[startIndex ..< suffix.startIndex], suffix: suffix)
  }

  public var leadingWhitespace: SubstringPair {
    return prefixAndSuffix(where: { $0.isWhitespace })
  }

  /// The substring of `self` that excludes any leading whitespace.
  public var strippingLeadingWhitespace: Substring {
    return leadingWhitespace.suffix
  }

  /// The substring of `self` that excludes any leading and trailing whitespace
  public var strippingLeadingAndTrailingWhitespace: Substring {
    return strippingLeadingWhitespace.suffixAndPrefix(where: { $0.isWhitespace }).prefix
  }

  /// True if the entire contents of the string is a valid table delimiter cell
  public var isTableDelimiterCell: Bool {
    return range(of: "^\\s*:?-+:?\\s*$", options: .regularExpression) != nil
  }
}
