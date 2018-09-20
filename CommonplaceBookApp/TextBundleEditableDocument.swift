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

  internal let document: TextBundleDocument
  weak var delegate: EditableDocumentDelegate?
}

extension TextBundleEditableDocument: TextBundleDocumentSaveListener {
  var key: String {
    return document.bundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }

  func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    guard let value = delegate?.editableDocumentCurrentText() else { return }
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
    delegate?.editableDocumentDidLoadText(text)
  }
}

extension TextBundleEditableDocument: ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction]) {
    renderers[.image] = { [weak self](node, attributes) in
      let imageNode = node as! MiniMarkdown.Image // swiftlint:disable:this force_cast
      let imagePath = imageNode.url.split(separator: "/").map { String($0) }
      let text = String(imageNode.slice.substring)
      guard let key = imagePath.last,
            let document = self?.document,
            let data = try? document.data(for: key, at: Array(imagePath.dropLast())),
            let image = UIImage(data: data)
        else {
          return RenderedMarkdownNode(
            type: .image,
            text: text,
            renderedResult: NSAttributedString(string: text, attributes: attributes.attributes)
          )
      }
      let attachment = NSTextAttachment()
      attachment.image = image
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
