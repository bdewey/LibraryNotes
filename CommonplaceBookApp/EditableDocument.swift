// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CwlSignal
import MiniMarkdown
import TextBundleKit
import UIKit

public protocol EditableDocument: class {
  var textSignal: Signal<Tagged<String>> { get }
  func applyTaggedModification(tag: Tag, modification: (String) -> String)
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
