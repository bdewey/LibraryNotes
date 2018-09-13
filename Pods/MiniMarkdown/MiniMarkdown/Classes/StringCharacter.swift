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

/// Represents a single character in a string.
/// By remembering the string and the index, StringCharacter structures can be efficiently
/// built up into StringSlice structures.
public struct StringCharacter {

  /// The underlying string.
  public let string: String

  /// The index of the character in the string.
  public let index: String.Index

  /// Returns the character.
  public var character: Character {
    return string[index]
  }

  /// Returns the character *before* this one, if it exists.
  public var previousCharacter: StringCharacter? {
    if index > string.startIndex {
      return StringCharacter(string: string, index: string.index(before: index))
    } else {
      return nil
    }
  }

  /// Adds two string characters, returning a StringSlice.
  /// - precondition: The characters must be from the same string and come sequentially
  ///                 in the string with no gaps.
  static public func + (lhs: StringCharacter, rhs: StringCharacter) -> StringSlice {
    return StringSlice(lhs) + StringSlice(rhs)
  }
}
