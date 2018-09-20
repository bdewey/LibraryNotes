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

/// Iterates through a string one line at a time, where lines are terminated by "\n",
/// Unlike Sequence.split, the delimiting "\n" *are* included in the sequence.
///
/// For example: "a\nb\nc\n".split("\n") == ["a", "b", "c"]
///              LineSequence("a\nb\nc\n") == ["a\n", "b\n", "c\n"]
public struct LineSequence {
  private let slice: StringSlice

  init(_ string: String) {
    self.slice = StringSlice(string)
  }

  init(_ slice: StringSlice) {
    self.slice = slice
  }
}

extension LineSequence: Sequence {

  public struct Iterator: IteratorProtocol {

    /// The string that we are iterating through.
    private let slice: StringSlice

    /// The start location of the next substring
    fileprivate var index: String.Index

    init(slice: StringSlice, index: String.Index) {
      self.slice = slice
      self.index = index
    }

    public mutating func next() -> StringSlice? {
      guard index < slice.range.upperBound else { return nil }
      let savedIndex = index
      self.index = nextIndex
      return StringSlice(string: slice.string, range: savedIndex ..< self.index)
    }

    /// Computes the next position of `index`
    private var nextIndex: String.Index {
      if let terminator = slice.substring[index...].firstIndex(of: "\n") {
        return slice.string.index(after: terminator)
      } else {
        return slice.range.upperBound
      }
    }
  }

  public func makeIterator() -> Iterator {
    return Iterator(slice: self.slice, index: self.slice.range.lowerBound)
  }
}

extension LineSequence {

  public var decomposed: (StringSlice, LineSequence)? {
    var iterator = makeIterator()
    guard let firstLine = iterator.next() else { return nil }
    let remainder = StringSlice(
      string: slice.string,
      range: iterator.index ..< slice.range.upperBound
    )
    return (firstLine, LineSequence(remainder))
  }
}
