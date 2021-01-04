// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

private extension CharacterSet {
  /// Checks if a character belongs to this CharacterSet.
  ///
  /// - parameter character: The character to test.
  /// - returns: `true` if the character is a single unicode scalar that is in `self`.
  func contains(_ character: Character) -> Bool {
    guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
      return false
    }
    return contains(scalar)
  }
}

/// Utility methods that helps Character work with the misnamed CharacterSet
/// (which really works with UnicodeScalar values).
public extension Character {
  /// `true` if CharacterSet.whitespacesAndNewlines contains `self`.
  var isWhitespaceOrNewline: Bool {
    return CharacterSet.whitespacesAndNewlines.contains(self)
  }

  /// `true` if CharacterSet.whitespaces contains `self`
  var isWhitespace: Bool {
    return CharacterSet.whitespaces.contains(self)
  }
}
