// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit
import MiniMarkdown
import TextBundleKit

public protocol EditableDocument: DocumentProtocol {
  var previousError: Swift.Error? { get }
  var text: NSAttributedString { get }
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
