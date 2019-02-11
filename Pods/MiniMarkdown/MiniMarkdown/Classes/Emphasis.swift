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

extension NodeType {
  public static let bold = NodeType(rawValue: "bold")
  public static let emphasis = NodeType(rawValue: "emphasis")
}

/// Emphasis: https://spec.commonmark.org/0.28/#emphasis-and-strong-emphasis
public final class Emphasis: DelimitedText, CharacterParseable {
  public init(delimitedSlice: DelimitedSlice) {
    super.init(type: .emphasis, delimitedSlice: delimitedSlice)
  }

  public static let parser = Emphasis.init <^> (
    CharacterParsers.slice(delimitedBy: "_") ||
      CharacterParsers.slice(delimitedBy: "*")
  )
}

/// Strong emphasis: https://spec.commonmark.org/0.28/#emphasis-and-strong-emphasis
public final class StrongEmphasis: DelimitedText, CharacterParseable {
  public init(slice: DelimitedSlice) {
    super.init(type: .bold, delimitedSlice: slice)
  }

  public static let parser = StrongEmphasis.init <^> CharacterParsers.slice(delimitedBy: "**")
}
