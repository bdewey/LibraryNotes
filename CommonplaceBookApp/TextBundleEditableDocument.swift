// Copyright © 2017-present Brian's Brain. All rights reserved.

import CwlSignal
import Foundation
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result

private let listenerKey = "org.brians-brain.CommonplaceBookApp.TextBundleDocumentListener"
private let placeholderImage = UIImage(named: "round_crop_original_black_24pt")!

extension TextBundleDocument: EditableDocument {
  public var currentTextResult: Result<Tagged<String>> {
    return text.taggedResult
  }

  public var textSignal: Signal<Tagged<String>> {
    return text.signal
  }

  public func applyTaggedModification(tag: Tag, modification: (String) -> String) {
    text.changeValue(tag: tag, mutation: modification)
  }

  public func close() {
    close(completionHandler: nil)
  }
}

extension TextBundleDocument: ConfiguresRenderers {
  public func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction]) {
    renderers[.image] = { _, _ in
      let attachment = NSTextAttachment()
      attachment.image = placeholderImage
      attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
      return NSAttributedString(attachment: attachment)
    }
  }
}
