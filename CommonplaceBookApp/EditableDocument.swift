// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit
import MiniMarkdown
import TextBundleKit

public protocol EditableDocumentDelegate: class {
  func editableDocumentDidLoadText(_ text: String)
  func editableDocumentCurrentText() -> String
}

public protocol EditableDocument: DocumentProtocol {
  var delegate: EditableDocumentDelegate? { get set }
  var previousError: Swift.Error? { get }
  func didUpdateText()
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
