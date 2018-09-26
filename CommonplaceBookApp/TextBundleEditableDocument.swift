// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

/// Wraps a TextStorage...
final class TextBundleEditableDocument: WrappingDocument {

  init(fileURL: URL) {
    self.document = TextBundleDocument(fileURL: fileURL)
    document.addListener(self)
  }

  init(document: TextBundleDocument) {
    self.document = document
    document.addListener(self)
  }

  internal let document: TextBundleDocument
  var dataConnection: EditableDocumentDataConnection?

  static let placeholderImage = UIImage(named: "round_crop_original_black_24pt")!
}

extension TextBundleEditableDocument: TextBundleDocumentSaveListener {
  var key: String {
    return document.bundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }

  func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    guard let value = dataConnection?.editableDocumentCurrentText() else { return }
    guard let data = value.data(using: .utf8) else {
      throw NSError.fileWriteInapplicableStringEncoding
    }
    let wrapper = FileWrapper(regularFileWithContents: data)
    document.bundle.replaceFileWrapper(wrapper, key: key)
  }

  func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    guard let data = try? document.data(for: key),
          let text = String(data: data, encoding: .utf8) else {
      assertionFailure()
      return
    }
    dataConnection?.editableDocumentDidLoadText(text)
  }
}

extension TextBundleEditableDocument: ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction]) {
    renderers[.image] = { (node, attributes) in
      let attachment = NSTextAttachment()
      attachment.image = TextBundleEditableDocument.placeholderImage
      attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
      let text = String(node.slice.substring)
      return RenderedMarkdownNode(
        type: .image,
        text: text,
        renderedResult: NSAttributedString(attachment: attachment)
      )
    }
  }
}

extension TextBundleEditableDocument: EditableDocument {
  public var previousError: Error? {
    return document.previousError
  }

  func didUpdateText() {
    document.updateChangeCount(.done)
  }
}
