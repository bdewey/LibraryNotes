// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import TextMarkupKit
import UIKit

public extension ParsedAttributedString.Style {
  static func plainText(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
    imageStorage: ParsedAttributedStringFormatter? = nil,
    kern: CGFloat = 0,
    fontDesign: UIFontDescriptor.SystemDesign = .default
  ) -> ParsedAttributedString.Style {
    var formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: .toggleItalic,
      .strongEmphasis: .toggleBold,
      .code: .fontDesign(.monospaced),
      .delimiter: .remove,
      .clozeHint: .remove,
    ]
    if let imageStorage = imageStorage {
      formatters[.image] = AnyParsedAttributedStringFormatter(imageStorage)
    }
    var defaultAttributes = AttributedStringAttributesDescriptor(textStyle: textStyle, color: textColor)
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.kern = kern
    defaultAttributes.fontDesign = fontDesign
    return ParsedAttributedString.Style(
      grammar: GrailDiaryGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )
  }
}
