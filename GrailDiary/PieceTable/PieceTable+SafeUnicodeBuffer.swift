// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
