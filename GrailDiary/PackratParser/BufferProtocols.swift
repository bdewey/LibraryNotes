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

/// A type that provides safe access to Int-indexed UTF-16 values.
public protocol SafeUnicodeBuffer {
  /// How many UTF-16 characters are in the buffer
  var count: Int { get }

  /// Gets the UTF-16 value at an index. If the index is out of bounds, returns nil.
  func utf16(at index: Int) -> unichar?

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
