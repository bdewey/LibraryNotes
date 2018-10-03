// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MiniMarkdown
import TextBundleKit

extension TextBundleDocument {
  internal static func makeTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) -> MiniMarkdownTextStorage {
    let textStorage = MiniMarkdownTextStorage(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    textStorage.defaultAttributes = NSAttributedString.Attributes(
      stylesheet.typographyScheme.body2
    )
    textStorage.defaultAttributes.kern = stylesheet.kern[.body2] ?? 1.0
    textStorage.defaultAttributes.color = stylesheet.colorScheme
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
    return textStorage
  }
}
