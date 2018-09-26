// Copyright © 2018 Brian's Brain. All rights reserved.

import MiniMarkdown
import TextBundleKit
import UIKit

public protocol EditableDocumentDataConnection {
  func editableDocumentDidLoadText(_ text: String)
  func editableDocumentCurrentText() -> String
}

public protocol EditableDocument: DocumentProtocol {
  var dataConnection: EditableDocumentDataConnection? { get set }
  var previousError: Swift.Error? { get }
  func didUpdateText()
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}
