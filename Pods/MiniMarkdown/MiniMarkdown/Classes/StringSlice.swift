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

/// Like a Substring, represents a slice of characters out of a string.
/// However, unlike a substring, adjacent StringSlice instances from the same string can
/// be efficiently combined.
public struct StringSlice: Equatable {

  /// The underlying substring.
  public let string: String

  /// The range of the slice.
  public let range: Range<String.Index>

  /// Initialize with a string and a slice.
  /// - parameter string: The root string.
  /// - parameter range: The range within `string` that defines this slice.
  public init(string: String, range: Range<String.Index>) {
    self.string = string
    self.range = range
  }

  /// Initialize with a string and a substring of that string.
  /// - parameter string: The root string
  /// - parameter substring: The substring of `string` that defines the slice.
  public init(string: String, substring: Substring) {
    self.string = string
    self.range = substring.startIndex ..< substring.endIndex
  }

  /// Create a StringSlice that represents an entire string.
  /// - parameter string: The string to convert.
  public init(_ string: String) {
    self.string = string
    self.range = string.completeRange
  }

  /// Contructs StringSlice from an NSRange in the character view.
  public init?(string: String, range: NSRange) {
    guard let indexRange = Range(range, in: string) else { return nil }
    self.init(string: string, range: indexRange)
  }

  public init(_ character: StringCharacter) {
    self.string = character.string
    self.range = character.index ..< character.string.index(after: character.index)
  }

  /// Return the substring corresponding to this slice.
  public var substring: Substring {
    return string[range]
  }

  /// Return the NSRange equivalent of the string range.
  public var nsRange: NSRange {
    return NSRange(range, in: string)
  }

  /// Checks if the specified slices cover every element of this slice
  public func covered(by subslices: [StringSlice]) -> Bool {
    var expectedBound = self.range.lowerBound
    for subslice in subslices {
      if subslice.range.lowerBound != expectedBound { return false }
      expectedBound = subslice.range.upperBound
    }
    return expectedBound == self.range.upperBound
  }

  public func dropFirst(_ countToDrop: Int) -> StringSlice {
    // Move the lower bound forward.
    let offsetLowerBound = string.index(range.lowerBound, offsetBy: countToDrop)
    return StringSlice(
      string: string,
      range: offsetLowerBound ..< range.upperBound
    )
  }

  /// Adds two slices.
  /// - precondition: The slices must come from the same string and must follow each other,
  ///                 sequentially. If there is a gap between lhs and rhs, it must contain only
  ///                 whitespace.
  static public func + (lhs: StringSlice, rhs: StringSlice) -> StringSlice {
    precondition(lhs.string == rhs.string)
    precondition(
      lhs
        .string[lhs.range.upperBound ..< rhs.range.lowerBound]
        .allSatisfy { $0.isWhitespaceOrNewline }
    )
    return StringSlice(string: lhs.string, range: lhs.range.lowerBound ..< rhs.range.upperBound)
  }

  static public func += (lhs: inout StringSlice, rhs: StringSlice) {
    lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
  }

  static public func + (lhs: StringSlice, rhs: StringCharacter) -> StringSlice {
    return lhs + StringSlice(rhs)
  }
}

/// A StringSlice is a collection of StringCharacters.
extension StringSlice: Collection {

  public var startIndex: String.Index {
    return range.lowerBound
  }

  public var endIndex: String.Index {
    return range.upperBound
  }

  public func index(after i: String.Index) -> String.Index {
    return string.index(after: i)
  }

  public subscript(i: String.Index) -> StringCharacter {
    return StringCharacter(string: string, index: i)
  }
}

extension Optional where Wrapped == StringSlice {

  /// Convenience: Adds a string slice to an optional string slice.
  static public func + (lhs: StringSlice?, rhs: StringSlice) -> StringSlice {
    if let lhs = lhs {
      return lhs + rhs
    } else {
      return rhs
    }
  }

  /// Convenience: Increments a string slice.
  static public func += (lhs: inout StringSlice?, rhs: StringSlice) {
    lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
  }
}

extension Array where Array.Element == StringCharacter {

  var stringSlice: StringSlice? {
    return self.reduce(nil) { (slice: StringSlice?, character: StringCharacter) -> StringSlice in
      return slice + StringSlice(character)
    }
  }
}
