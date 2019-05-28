// Copyright © 2018-present Brian's Brain. All rights reserved.

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
        attributes: attributes
      )
    }
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = stylesheet.attributes(style: style)
    defaultAttributes.lineHeightMultiple = 1.2
  }
}

extension MarkdownAttributedStringRenderer {
  public init(
    stylesheet: Stylesheet,
    style: Stylesheet.Style
  ) {
    self.init()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.bold] = { $1.bold = true }
    renderFunctions[.delimiter] = { _, _ in NSAttributedString() }
    renderFunctions[.cloze] = { node, attributes in
      guard let cloze = node as? Cloze else {
        assertionFailure()
        return NSAttributedString()
      }
      return NSAttributedString(
        string: String(cloze.hiddenText),
        attributes: attributes
      )
    }
    defaultAttributes = stylesheet.attributes(style: style)
    defaultAttributes.lineHeightMultiple = 1.2
  }
}
