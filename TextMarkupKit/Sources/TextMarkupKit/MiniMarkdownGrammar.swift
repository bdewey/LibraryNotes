// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension SyntaxTreeNodeType {
  static let blankLine: SyntaxTreeNodeType = "blank_line"
  static let blockquote: SyntaxTreeNodeType = "blockquote"
  static let code: SyntaxTreeNodeType = "code"
  static let delimiter: SyntaxTreeNodeType = "delimiter"
  static let document: SyntaxTreeNodeType = "document"
  static let emphasis: SyntaxTreeNodeType = "emphasis"
  static let hashtag: SyntaxTreeNodeType = "hashtag"
  static let header: SyntaxTreeNodeType = "header"
  static let image: SyntaxTreeNodeType = "image"
  static let linkAltText: SyntaxTreeNodeType = "link_alt_text"
  static let linkTarget: SyntaxTreeNodeType = "link_target"
  static let list: SyntaxTreeNodeType = "list"
  static let listDelimiter: SyntaxTreeNodeType = "list_delimiter"
  static let listItem: SyntaxTreeNodeType = "list_item"
  static let paragraph: SyntaxTreeNodeType = "paragraph"
  static let softTab: SyntaxTreeNodeType = "tab"
  static let strongEmphasis: SyntaxTreeNodeType = "strong_emphasis"
  static let text: SyntaxTreeNodeType = "text"
  static let unorderedListOpening: SyntaxTreeNodeType = "unordered_list_opening"
  static let orderedListNumber: SyntaxTreeNodeType = "ordered_list_number"
  static let orderedListTerminator: SyntaxTreeNodeType = "ordered_list_terminator"
  static let summaryDelimiter: SyntaxTreeNodeType = "summary_delimiter"
  static let summaryBody: SyntaxTreeNodeType = "summary_body"
  static let summary: SyntaxTreeNodeType = "summary"
  static let emoji: SyntaxTreeNodeType = "emoji"
}

public enum ListType {
  case ordered
  case unordered
}

public enum ListTypeKey: SyntaxTreeNodePropertyKey {
  public typealias Value = ListType

  public static let key = "list_type"
}

/// Implements a subset of Markdown for common "plain text formatting" scenarios.
///
/// This class is designed to be subclassed so you can extend the grammar. Subclasses can override:
public final class MiniMarkdownGrammar: PackratGrammar {
  public init(
    trace: Bool = false
  ) {
    if trace {
      self.start = start.trace()
    }
  }

  /// Singleton for convenience.
  public static let shared = MiniMarkdownGrammar()

  public private(set) lazy var start: ParsingRule = block.memoize()
    .repeating(0...)
    .wrapping(in: .document)

  private lazy var coreBlockRules = [
    blankLine,
    header,
    unorderedList,
    orderedList,
    blockquote,
    summary,
  ]

  public var customBlockRules: [ParsingRule] = [] {
    didSet {
      var resolvedRules = coreBlockRules
      resolvedRules.append(contentsOf: customBlockRules)
      // `paragraph` goes last because it matches everything. No rule after `paragraph` will ever run.
      resolvedRules.append(paragraph)
      block.rules = resolvedRules
    }
  }

  private lazy var block: Choice = {
    var resolvedRules = coreBlockRules
    resolvedRules.append(contentsOf: customBlockRules)
    // `paragraph` goes last because it matches everything. No rule after `paragraph` will ever run.
    resolvedRules.append(paragraph)

    return Choice(resolvedRules)
  }()

  lazy var blankLine = InOrder(
    whitespace.repeating(0...),
    newline
  ).as(.blankLine).memoize()

  lazy var header = InOrder(
    Characters(["#"]).repeating(1 ..< 7).as(.delimiter),
    softTab,
    singleLineStyledText
  ).wrapping(in: .header).memoize()

  lazy var summary = InOrder(
    Choice(
      InOrder(Literal("Summary: ", compareOptions: [.caseInsensitive]).as(.summaryDelimiter)),
      InOrder(Literal("tl;dr: ", compareOptions: [.caseInsensitive]).as(.summaryDelimiter))
    ),
    singleLineStyledText.wrapping(in: .summaryBody)
  ).wrapping(in: .summary).memoize()

  lazy var paragraph = InOrder(
    nonDelimitedHashtag.zeroOrOne(),
    styledText,
    paragraphTermination.zeroOrOne().wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  public private(set) lazy var paragraphTermination = InOrder(
    newline,
    Choice(Characters(["#", "\n"]).assert(), unorderedListOpening.assert(), orderedListOpening.assert(), blockquoteOpening.assert())
  )

  // MARK: - Inline styles

  func delimitedText(_ nodeType: SyntaxTreeNodeType, delimiter: ParsingRule) -> ParsingRule {
    let rightFlanking = InOrder(nonWhitespace.as(.text), delimiter.as(.delimiter)).memoize()
    return InOrder(
      delimiter.as(.delimiter),
      nonWhitespace.assert(),
      InOrder(
        rightFlanking.assertInverse(),
        paragraphTermination.assertInverse(),
        dot
      ).repeating(0...).as(.text),
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
  lazy var nonDelimitedHashtag = InOrder(
    Literal("#").as(.text),
    Choice(emoji, nonWhitespace.as(.text)).repeating(1...)
  ).wrapping(in: .hashtag).memoize()

  lazy var image = InOrder(
    Literal("![").as(.text),
    Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...).as(.linkAltText),
    Literal("](").as(.text),
    Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...).as(.linkTarget),
    Literal(")").as(.text)
  ).wrapping(in: .image).memoize()

  lazy var emoji = CharacterPredicate { $0.isEmoji }.repeating(1...).as(.emoji).memoize()

  /// Rules that define how to parse "inline styles" (bold, italic, code, etc). Designed to be overridden to add or replace the parsed inline styles.
  private lazy var inlineStyleRules: [ParsingRule] = [
    bold,
    italic,
    underlineItalic,
    code,
    hashtag,
    image,
    emoji,
  ]

  public var customInlineStyleRules: [ParsingRule] = [] {
    didSet {
      var resolvedStyleRules = inlineStyleRules
      resolvedStyleRules.append(contentsOf: customInlineStyleRules)
      unmemoizedTextStyles.rules = resolvedStyleRules
    }
  }

  private lazy var unmemoizedTextStyles = Choice(inlineStyleRules)

  private lazy var textStyles = unmemoizedTextStyles.memoize()

  lazy var styledText = InOrder(
    InOrder(paragraphTermination.assertInverse(), textStyles.assertInverse(), dot).repeating(0...).as(.text),
    textStyles.repeating(0...)
  ).repeating(0...).memoize()

  /// A variant of `styledText` that terminates on the first newline
  public private(set) lazy var singleLineStyledText = InOrder(
    InOrder(Characters(["\n"]).assertInverse(), textStyles.assertInverse(), dot).repeating(0...).as(.text),
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
    whitespace.repeating(0 ... 3).as(.text),
    Characters([">"]).as(.text),
    whitespace.zeroOrOne().as(.softTab)
  ).wrapping(in: .delimiter).memoize()

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
  ).wrapping(in: .listDelimiter).memoize()

  lazy var orderedListOpening = InOrder(
    whitespace.repeating(0...).as(.text).zeroOrOne(),
    digit.repeating(1 ... 9).as(.orderedListNumber),
    Characters([".", ")"]).as(.orderedListTerminator),
    whitespace.repeating(1 ... 4).as(.softTab)
  ).wrapping(in: .listDelimiter).memoize()

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

private extension Character {
  var isSimpleEmoji: Bool {
    guard let firstScalar = unicodeScalars.first else {
      return false
    }
    return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
  }

  var isCombinedIntoEmoji: Bool {
    unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false
  }

  var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}
