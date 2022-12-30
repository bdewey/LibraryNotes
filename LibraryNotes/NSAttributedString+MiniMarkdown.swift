// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import NaturalLanguage
import TextMarkupKit
import UIKit

public extension ParsedAttributedString.Style {
  static let defaultRichTextEditing: ParsedAttributedString.Style = {
    var attributes = AttributedStringAttributesDescriptor.standardAttributes()
    attributes.paragraphSpacing = 20
    var style = GrailDiaryGrammar.defaultEditingStyle(defaultAttributes: attributes)
    style.formatters[.blockquote] = AnyParsedAttributedStringFormatter {
      $0.italic = true
      $0.blockquoteBorderColor = UIColor.systemOrange
    }
    style.formatters[.text] = .removeNewlines
    style.formatters[.blankLine] = .remove
    style.formatters[.delimiter] = .remove
    style.formatters[.clozeHint] = .remove
    return style
  }()
}

private extension UInt16 {
  static let newline = "\n".utf16.first!
  static let space = " ".utf16.first!
}

/// Removes all but the last newline in a node.
struct RemoveNewlineFormatter: ParsedAttributedStringFormatter {
  func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    var replacement = buffer[NSRange(location: offset, length: node.length)]
    for (index, unichar) in replacement.dropLast().enumerated() where unichar == .newline {
      replacement[index] = .space
    }
    return (currentAttributes, replacement)
  }
}

extension AnyParsedAttributedStringFormatter {
  static let removeNewlines = AnyParsedAttributedStringFormatter(RemoveNewlineFormatter())
}

public extension NSAttributedString {
  /// Construct an `NSAttributedString` from a plain-text Mini-Markdown `String`.
  convenience init(miniMarkdown: String, style: ParsedAttributedString.Style = .defaultRichTextEditing) {
    let parsedAttributedString = ParsedAttributedString(string: miniMarkdown, style: style)
    self.init(attributedString: parsedAttributedString)
  }

  /// Constructs a mini-markdown string that would yield the formatting present in this attributed string.
  func makeMiniMarkdown() -> String {
    var results = ""
    let tokenizer = NLTokenizer(unit: .paragraph)
    tokenizer.string = string
    tokenizer.enumerateTokens(in: string.startIndex ..< string.endIndex) { paragraphRange, _ in
      if !results.isEmpty {
        results.append("\n")
      }
      results.append(contentsOf: string[paragraphRange])
      return true
    }
    return results
  }
}
