// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension RenderedMarkdown {
  /// Convenience initializer for a RenderedMarkdown that uses a style in a Stylesheet.
  /// Knows how to render clozes, etc.
  @available(*, deprecated)
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
    renderers[.clozeHint] = { _, _ in NSAttributedString() }
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = stylesheet.attributes(style: style)
    defaultAttributes.lineHeightMultiple = 1.2
  }

  /// Convenience initializer for a RenderedMarkdown that uses a specific TextStyle.
  /// Hides delimiters and cloze hints.
  public convenience init(
    textStyle: UIFont.TextStyle,
    parsingRules: ParsingRules
  ) {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.emphasis] = { $1.italic = true }
    formatters[.bold] = { $1.bold = true }
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.delimiter] = { _, _ in NSAttributedString() }
    renderers[.clozeHint] = { _, _ in NSAttributedString() }
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: textStyle),
      .foregroundColor: UIColor.label,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
  }
}

extension MarkdownAttributedStringRenderer {
  @available(*, deprecated)
  public init(
    stylesheet: Stylesheet,
    style: Stylesheet.Style
  ) {
    self.init()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.bold] = { $1.bold = true }
    renderFunctions[.delimiter] = { _, _ in NSAttributedString() }
    renderFunctions[.clozeHint] = { _, _ in NSAttributedString() }
    defaultAttributes = stylesheet.attributes(style: style)
    defaultAttributes.lineHeightMultiple = 1.2
  }

  public init(
    textStyle: UIFont.TextStyle
  ) {
    self.init()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.bold] = { $1.bold = true }
    renderFunctions[.delimiter] = { _, _ in NSAttributedString() }
    renderFunctions[.clozeHint] = { _, _ in NSAttributedString() }
    defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: textStyle),
      .foregroundColor: UIColor.label,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
  }
}
