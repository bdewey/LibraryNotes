// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

/// Wraps a TextStorage...
final class MarkdownFixupTextBundle {

  init(fileURL: URL) {
    self.textStorage = TextStorage(document: TextBundleDocument(fileURL: fileURL))
  }

  private let textStorage: TextStorage
  private lazy var mutableText: NSMutableAttributedString = {
    let markdown = textStorage.text.currentResult.value ?? ""
    // TODO: This is wrong.
    return NSMutableAttributedString(string: markdown)
  }()
}

extension MarkdownFixupTextBundle: ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType : RenderedMarkdown.RenderFunction]) {
    renderers[.image] = { [weak self](node, attributes) in
      let imageNode = node as! MiniMarkdown.Image
      let imagePath = imageNode.url.split(separator: "/").map { String($0) }
      let text = String(imageNode.slice.substring)
      guard let key = imagePath.last,
            let document = self?.textStorage.document,
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

extension MarkdownFixupTextBundle: WrappingDocument {
  var document: TextBundleDocument { return textStorage.document }
}

extension MarkdownFixupTextBundle: EditableDocument {

  public var previousError: Error? {
    return document.previousError
  }

  public var text: NSAttributedString {
    return mutableText
  }
}

extension NSMutableAttributedString {
  public func applyChange<C: Collection>(
    _ change: RangeReplaceableChange<C>
  ) where C.Element == Character {
    self.replaceCharacters(in: change.range, with: String(change.newElements))
  }
}
