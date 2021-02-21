// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A type that provides safe access to Int-indexed UTF-16 values.
public protocol SafeUnicodeBuffer {
  /// How many UTF-16 characters are in the buffer
  var count: Int { get }

  /// Gets the UTF-16 value at an index. If the index is out of bounds, returns nil.
  func utf16(at index: Int) -> unichar?

  /// Gets a Character that starts at index. Note that Character may be composed of several UTF-16 code units. (E.g., emoji)
  func character(at index: Int) -> Character?

  /// Gets a substring from the buffer, objc-style
  subscript(range: NSRange) -> [unichar] { get }

  /// The contents of the receiver as a string.
  var string: String { get }
}

/// Make every String a SafeUnicodeBuffer
extension String: SafeUnicodeBuffer {
  public subscript(range: NSRange) -> [unichar] {
    guard
      let lowerBound = index(startIndex, offsetBy: range.location, limitedBy: endIndex),
      let upperBound = index(lowerBound, offsetBy: range.length, limitedBy: endIndex)
    else {
      return []
    }
    return Array(utf16[lowerBound ..< upperBound])
  }

  public func utf16(at i: Int) -> unichar? {
    guard let stringIndex = index(startIndex, offsetBy: i, limitedBy: endIndex), stringIndex < endIndex else {
      return nil
    }
    return utf16[stringIndex]
  }

  public func character(at i: Int) -> Character? {
    guard let stringIndex = index(startIndex, offsetBy: i, limitedBy: endIndex), stringIndex < endIndex else {
      return nil
    }
    return self[stringIndex]
  }

  public var string: String { self }
}

public protocol RangeReplaceableSafeUnicodeBuffer: SafeUnicodeBuffer {
  /// Replace the UTF-16 values stored in `range` with the values from `str`.
  mutating func replaceCharacters(in range: NSRange, with str: String)
}

public enum ParsingError: Swift.Error {
  /// The supplied grammar did not parse the entire contents of the buffer.
  /// - parameter length: How much of the buffer was consumed by the grammar.
  case incompleteParsing(length: Int)

  /// We just didn't feel like parsing today -- used mostly to test error paths :-)
  case didntFeelLikeIt
}
