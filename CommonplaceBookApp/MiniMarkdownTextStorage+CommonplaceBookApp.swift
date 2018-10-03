// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MiniMarkdown
import TextBundleKit

extension MiniMarkdownTextStorage {
  internal convenience init(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) {
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = NSAttributedString.Attributes(
      stylesheet.typographyScheme.body2
    )
    defaultAttributes.kern = stylesheet.kern[.body2] ?? 1.0
    defaultAttributes.color = stylesheet.colorScheme
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
  }
}
