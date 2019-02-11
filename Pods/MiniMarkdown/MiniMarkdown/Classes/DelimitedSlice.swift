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

/// A slice flanked by optional left and right delimiters.
public struct DelimitedSlice {
  public init(
    leftDelimiter: Delimiter,
    slice: StringSlice?,
    rightDelimiter: Delimiter
  ) {
    self.leftDelimiter = leftDelimiter
    self.slice = slice
    self.rightDelimiter = rightDelimiter
  }

  public init(
    leftDelimiter: StringSlice,
    characters: [StringCharacter],
    rightDelimiter: StringSlice
  ) {
    self.leftDelimiter = Delimiter(leftDelimiter)
    self.slice = characters.stringSlice
    self.rightDelimiter = Delimiter(rightDelimiter)
  }

  public let leftDelimiter: Delimiter
  public let slice: StringSlice?
  public let rightDelimiter: Delimiter

  public var completeSlice: StringSlice {
    return leftDelimiter.slice + (slice + rightDelimiter.slice)
  }
}
