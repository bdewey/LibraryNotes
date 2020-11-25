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

// MARK: - SafeUnicodeBuffer

extension PieceTable: SafeUnicodeBuffer {
  /// Returns the unicode characters at a specific range.
  public subscript(range: NSRange) -> [unichar] {
    let tableRange = Range(range, in: self)!
    return self[tableRange]
  }

  /// Returns a single unicode character at a specific index. If the index is at or after the end of the buffer contents, returns nil.
  public func utf16(at index: Int) -> unichar? {
    guard let tableIndex = self.index(startIndex, offsetBy: index, limitedBy: endIndex), tableIndex < endIndex else {
      return nil
    }
    return self[tableIndex]
  }
}

extension PieceTable: RangeReplaceableSafeUnicodeBuffer {
  /// Replace the utf16 scalars in a range with the utf16 scalars from a string.
  public mutating func replaceCharacters(in range: NSRange, with str: String) {
    let tableRange = Range(range, in: self)!
    replaceSubrange(tableRange, with: str.utf16)
  }
}
