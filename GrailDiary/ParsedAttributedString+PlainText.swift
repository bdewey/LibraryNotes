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
    var formattingFunctions = [SyntaxTreeNodeType: QuickFormatFunction]()
    var replacementFunctions = [SyntaxTreeNodeType: FullFormatFunction]()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.strongEmphasis] = { $1.bold = true }
    formattingFunctions[.code] = { $1.fontDesign = .monospaced }
    replacementFunctions[.delimiter] = { _, _, _, _ in [] }
    replacementFunctions[.clozeHint] = { _, _, _, _ in [] }
    if let imageStorage = imageStorage {
      replacementFunctions[.image] = imageStorage.imageReplacement
    }
    var defaultAttributes = AttributedStringAttributesDescriptor(textStyle: textStyle, color: textColor)
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.kern = kern
    defaultAttributes.fontDesign = fontDesign
    return ParsedAttributedString.Settings(
      grammar: GrailDiaryGrammar(),
      defaultAttributes: defaultAttributes,
      quickFormatFunctions: formattingFunctions,
      fullFormatFunctions: replacementFunctions
    )
  }
}
