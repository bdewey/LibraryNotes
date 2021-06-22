// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import TextMarkupKit
import UIKit

public extension ParsedAttributedString.Settings {
  static func plainText(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
    imageStorage: ImageStorage? = nil,
    kern: CGFloat = 0,
    fontDesign: UIFontDescriptor.SystemDesign = .default
  ) -> ParsedAttributedString.Settings {
    var formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: .toggleItalic,
      .strongEmphasis: .toggleBold,
      .code: .fontDesign(.monospaced),
      .delimiter: .remove,
      .clozeHint: .remove,
    ]
    if let imageStorage = imageStorage {
      formatters[.image] = AnyParsedAttributedStringFormatter(ImageReplacementFormatter(imageStorage))
    }
    var defaultAttributes = AttributedStringAttributesDescriptor(textStyle: textStyle, color: textColor)
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.kern = kern
    defaultAttributes.fontDesign = fontDesign
    return ParsedAttributedString.Settings(
      grammar: GrailDiaryGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )
  }
}
