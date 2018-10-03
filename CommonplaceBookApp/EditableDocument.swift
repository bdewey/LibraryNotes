// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import MiniMarkdown
import TextBundleKit
import UIKit

public protocol EditableDocument: class {
  func markdownTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) -> MiniMarkdownTextStorage
}
