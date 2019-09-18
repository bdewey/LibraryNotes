// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import UIKit

extension RenderedMarkdown {
  /// Convenience initializer for a RenderedMarkdown that uses a specific TextStyle.
  /// Hides delimiters and cloze hints.
  public convenience init(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
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
      .foregroundColor: textColor,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
  }

  /// Makes a RenderedMarkdown for rendering document titles in a list.
  public static func makeTitleRenderer() -> RenderedMarkdown {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.emphasis] = { $1.italic = true }
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.delimiter] = { _, _ in NSAttributedString() }
    let renderer = RenderedMarkdown(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
    renderer.defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .headline),
      .foregroundColor: UIColor.label,
    ]
    return renderer
  }
}

extension MarkdownAttributedStringRenderer {
  public init(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
    extraAttributes: [NSAttributedString.Key: Any] = [:]
  ) {
    self.init()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.bold] = { $1.bold = true }
    formattingFunctions[.codeSpan] = { $1.familyName = "Menlo" }
    renderFunctions[.delimiter] = { _, _ in NSAttributedString() }
    renderFunctions[.clozeHint] = { _, _ in NSAttributedString() }
    defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: textStyle),
      .foregroundColor: textColor,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.merge(extraAttributes, uniquingKeysWith: { _, new in new })
  }
}
