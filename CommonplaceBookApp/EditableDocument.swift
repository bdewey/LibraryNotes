// Copyright © 2018 Brian's Brain. All rights reserved.

import MiniMarkdown
import TextBundleKit
import UIKit

public protocol EditableDocument: class {
  var markdownTextStorage: MiniMarkdownTextStorage? { get set }
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
