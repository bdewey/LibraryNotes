// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import CoreGraphics
import LibraryNotesCore
import TextMarkupKit

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

extension ParsedAttributedString.Style {
  static func plainText(
    textStyle: TextMarkupKitTextStyle,
    textColor: TextMarkupKitColor? = nil,
    imageStorage: ParsedAttributedStringFormatter? = nil,
    kern: CGFloat = 0,
    fontDesign: TextMarkupKitFontDesign? = nil
  ) -> ParsedAttributedString.Style {
    var formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: .toggleItalic,
      .strongEmphasis: .toggleBold,
      .code: .fontDesign(.monospaced),
      .delimiter: .remove,
      .clozeHint: .remove,
    ]
    if let imageStorage {
      formatters[.image] = AnyParsedAttributedStringFormatter(imageStorage)
    }
    var defaultAttributes = AttributedStringAttributesDescriptor(textStyle: textStyle, color: textColor)
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.kern = kern
    defaultAttributes.fontDesign = fontDesign ?? .default
    return ParsedAttributedString.Style(
      grammar: GrailDiaryGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )
  }
}
