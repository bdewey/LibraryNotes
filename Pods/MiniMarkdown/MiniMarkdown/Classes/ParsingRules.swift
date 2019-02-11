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

/// This structure encapsulates how to parse a MiniMarkdown document.
public struct ParsingRules {
  // Does nothing; just allows public construction.
  public init() {}

  /// An ordered list of block-level parsers.
  ///
  /// - note: Block parsers operate on one line at a time.
  public var blockParsers = ParsingArray([
    Heading.nodeParser,
    List.nodeParser,
    Table.nodeParser,
    BlockQuote.nodeParser,
    BlankLine.nodeParser,
    Paragraph.nodeParser,
  ])

  /// An ordered list of inline parsers.
  ///
  /// Inline parsers look at each individual character.
  public var inlineParsers = ParsingArray([
    Emphasis.nodeParser,
    StrongEmphasis.nodeParser,
    Image.nodeParser,
    Hashtag.nodeParser,
    Text.nodeParser,
  ])

  /// Parses a sequence of lines for block structures.
  public func parse(_ lines: ArraySlice<StringSlice>) -> [Node] {
    let blockNodes = blockParsers.parse(lines)
    for block in blockNodes {
      block.parsingRules = self
    }
    return blockNodes
  }

  public func parse(_ characters: ArraySlice<StringCharacter>) -> [Node] {
    let blockNodes = inlineParsers.parse(characters)
    for block in blockNodes {
      block.parsingRules = self
    }
    return blockNodes
  }

  public func parse(_ markdown: String) -> [Node] {
    let results = parse(ArraySlice(LineSequence(markdown)))
    assert(results.allMarkdown == markdown)
    return results
  }
}
