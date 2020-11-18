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
