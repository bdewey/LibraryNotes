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

public extension NewNodeType {
  static let blankLine: NewNodeType = "blank_line"
  static let blockquote: NewNodeType = "blockquote"
  static let code: NewNodeType = "code"
  static let delimiter: NewNodeType = "delimiter"
  static let document: NewNodeType = "document"
  static let emphasis: NewNodeType = "emphasis"
  static let hashtag: NewNodeType = "hashtag"
  static let header: NewNodeType = "header"
  static let image: NewNodeType = "image"
  static let list: NewNodeType = "list"
  static let listItem: NewNodeType = "list_item"
  static let paragraph: NewNodeType = "paragraph"
  static let softTab: NewNodeType = "tab"
  static let strongEmphasis: NewNodeType = "strong_emphasis"
  static let text: NewNodeType = "text"
  static let unorderedListOpening: NewNodeType = "unordered_list_opening"
  static let orderedListNumber: NewNodeType = "ordered_list_number"
  static let orderedListTerminator: NewNodeType = "ordered_list_terminator"
}

public enum ListType {
  case ordered
  case unordered
}

public enum ListTypeKey: NodePropertyKey {
  public typealias Value = ListType

  public static let key = "list_type"
}

public final class MiniMarkdownGrammar: PackratGrammar {
  public init(trace: Bool = false) {
    if trace {
      self.start = self.start.trace()
    }
  }

  /// Singleton for convenience.
  public static let shared = MiniMarkdownGrammar()

  public private(set) lazy var start: ParsingRule = block
    .repeating(0...)
    .wrapping(in: .document)

  lazy var block = Choice(
    blankLine,
    header,
    unorderedList,
    orderedList,
    blockquote,
    paragraph
  ).memoize()

  lazy var blankLine = InOrder(
    whitespace.repeating(0...),
    newline
  ).as(.blankLine).memoize()

  lazy var header = InOrder(
    Characters(["#"]).repeating(1 ..< 7).as(.delimiter),
    softTab,
    InOrder(
      InOrder(newline.assertInverse(), dot).repeating(0...),
      Choice(newline, dot.assertInverse())
    ).as(.text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    nonDelimitedHashtag.zeroOrOne(),
    styledText,
    paragraphTermination.zeroOrOne().wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Choice(Characters(["#", "\n"]).assert(), unorderedListOpening.assert(), orderedListOpening.assert(), blockquoteOpening.assert())
  )

  // MARK: - Inline styles

  func delimitedText(_ nodeType: NewNodeType, delimiter: ParsingRule) -> ParsingRule {
    let rightFlanking = InOrder(nonWhitespace.as(.text), delimiter.as(.delimiter)).memoize()
    return InOrder(
      delimiter.as(.delimiter),
      nonWhitespace.assert(),
      InOrder(
        rightFlanking.assertInverse(),
        paragraphTermination.assertInverse(),
        dot
      ).repeating(1...).as(.text),
      rightFlanking
    ).wrapping(in: nodeType).memoize()
  }

  lazy var bold = delimitedText(.strongEmphasis, delimiter: Literal("**"))
  lazy var italic = delimitedText(.emphasis, delimiter: Literal("*"))
  lazy var underlineItalic = delimitedText(.emphasis, delimiter: Literal("_"))
  lazy var code = delimitedText(.code, delimiter: Literal("`"))
  lazy var hashtag = InOrder(
    whitespace.as(.text),
    nonDelimitedHashtag
  )
  lazy var nonDelimitedHashtag = InOrder(Literal("#"), nonWhitespace.repeating(1...)).as(.hashtag).memoize()

  lazy var image = InOrder(
    Literal("!["),
    Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...),
    Literal("]("),
    Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...),
    Literal(")")
  ).as(.image).memoize()

  lazy var textStyles = Choice(
    bold,
    italic,
    underlineItalic,
    code,
    hashtag,
    image
  ).memoize()

  lazy var styledText = InOrder(
    InOrder(paragraphTermination.assertInverse(), textStyles.assertInverse(), dot).repeating(0...).as(.text),
    textStyles.repeating(0...)
  ).repeating(0...).memoize()

  // MARK: - Character primitives

  let dot = DotRule()
  let newline = Characters(["\n"])
  let whitespace = Characters(.whitespaces)
  let nonWhitespace = Characters(CharacterSet.whitespacesAndNewlines.inverted)
  let digit = Characters(.decimalDigits)
  /// One or more whitespace characters that should be interpreted as a single delimiater.
  let softTab = Characters(.whitespaces).repeating(1...).as(.softTab)

  // MARK: - Simple block quotes

  // TODO: Support single block quotes that span multiple lines, and block quotes with multiple
  //       paragraphs.

  lazy var blockquoteOpening = InOrder(
    whitespace.repeating(0 ... 3),
    Characters([">"]),
    whitespace.zeroOrOne()
  ).as(.delimiter).memoize()

  lazy var blockquote = InOrder(
    blockquoteOpening,
    paragraph
  ).as(.blockquote).memoize()

  // MARK: - Lists

  // https://spec.commonmark.org/0.28/#list-items

  lazy var unorderedListOpening = InOrder(
    whitespace.repeating(0...).as(.text).zeroOrOne(),
    Characters(["*", "-", "+"]).as(.unorderedListOpening),
    whitespace.repeating(1 ... 4).as(.softTab)
  ).wrapping(in: .delimiter).memoize()

  lazy var orderedListOpening = InOrder(
    whitespace.repeating(0...).as(.text).zeroOrOne(),
    digit.repeating(1 ... 9).as(.orderedListNumber),
    Characters([".", ")"]).as(.orderedListTerminator),
    whitespace.repeating(1 ... 4).as(.softTab)
  ).wrapping(in: .delimiter).memoize()

  func list(type: ListType, openingDelimiter: ParsingRule) -> ParsingRule {
    let listItem = InOrder(
      openingDelimiter,
      paragraph
    ).wrapping(in: .listItem).memoize()
    return InOrder(
      listItem,
      blankLine.repeating(0...)
    ).repeating(1...).wrapping(in: .list).property(key: ListTypeKey.self, value: type).memoize()
  }

  lazy var unorderedList = list(type: .unordered, openingDelimiter: unorderedListOpening)
  lazy var orderedList = list(type: .ordered, openingDelimiter: orderedListOpening)
}
