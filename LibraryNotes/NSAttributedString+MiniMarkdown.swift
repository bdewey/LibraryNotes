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
    enumerateAttributes(in: NSRange(location: 0, length: length)) { attributes, range, _ in
      if attributes.symbolicTraits.contains(.traitBold) {
        results.append("**")
      } else if attributes.symbolicTraits.contains(.traitItalic) {
        results.append("_")
      }
      let foo = self.string[range]
      var str = String(utf16CodeUnits: foo, count: foo.count)
      str.replace("\n", with: "\n\n")
      results += str
      if attributes.symbolicTraits.contains(.traitBold) {
        results.append("**")
      } else if attributes.symbolicTraits.contains(.traitItalic) {
        results.append("_")
      }
    }
    return results
  }
}

private extension [NSAttributedString.Key: Any] {
  var symbolicTraits: UIFontDescriptor.SymbolicTraits {
    if let font = self[.font] as? UIFont {
      return font.fontDescriptor.symbolicTraits
    } else {
      return .init()
    }
  }
}
