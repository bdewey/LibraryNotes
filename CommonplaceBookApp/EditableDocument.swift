// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CwlSignal
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result
import UIKit

public protocol EditableDocument: class {
  var currentTextResult: Result<Tagged<String>> { get }
  var textSignal: Signal<Tagged<String>> { get }
  func applyTaggedModification(tag: Tag, modification: (String) -> String)
  func close()
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
