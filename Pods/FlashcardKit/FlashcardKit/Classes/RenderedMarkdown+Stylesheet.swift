// Copyright © 2018-present Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MiniMarkdown

extension RenderedMarkdown {
  /// Convenience initializer for a RenderedMarkdown that uses a style in a Stylesheet.
  /// Knows how to render clozes, etc.
  public convenience init(
    stylesheet: Stylesheet,
    style: Stylesheet.Style,
    parsingRules: ParsingRules
  ) {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.emphasis] = { $1.italic = true }
    formatters[.bold] = { $1.bold = true }
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.delimiter] = { _, _ in NSAttributedString() }
    renderers[.cloze] = { node, attributes in
      guard let cloze = node as? Cloze else {
        assertionFailure()
        return NSAttributedString()
      }
      return NSAttributedString(
        string: String(cloze.hiddenText),
        attributes: attributes.attributes
      )
    }
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = NSAttributedString.Attributes(
      stylesheet.typographyScheme[style]
    )
    defaultAttributes.kern = stylesheet.kern[style] ?? 1.0
    defaultAttributes.alignment = .left
  }
}
