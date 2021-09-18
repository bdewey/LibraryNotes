// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import TextMarkupKit
import UIKit

extension GrailDiaryGrammar {
  /// An editing style for `GrailDiaryGrammar` strings, based on the `MiniMarkdownGrammar` default editing style.
  static func defaultEditingStyle() -> ParsedAttributedString.Style {
    var baseStyle = MiniMarkdownGrammar.defaultEditingStyle()
    let formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .questionAndAnswer: .incrementListLevel,
      .qnaDelimiter: .toggleBold,
      .cloze: .backgroundColor(.systemYellow.withAlphaComponent(0.3)),
      .clozeHint: .color(.secondaryLabel),
      .summaryDelimiter: .toggleBold,
      .summary: AnyParsedAttributedStringFormatter {
        $0.blockquoteBorderColor = UIColor.systemOrange
        $0.italic = true
      },
      .hashtag: .backgroundColor(.grailSecondaryBackground),
    ]
    baseStyle.grammar = GrailDiaryGrammar.shared
    baseStyle.formatters.merge(formatters, uniquingKeysWith: { _, newValue in newValue })
    return baseStyle
  }
}
