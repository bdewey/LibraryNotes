// Copyright © 2018 Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

/// Custom UITextView subclass that overrides "copy" to copy Markdown.
/// TODO: Move renderers, MiniMarkdown text storage management, etc. to this class.
public final class MarkdownEditingTextView: UITextView {

  override public func copy(_ sender: Any?) {
    let markdownTextStorage = textStorage as! MiniMarkdownTextStorage
    guard let range = markdownTextStorage.markdownRange(for: selectedRange) else { return }
    UIPasteboard.general.string = String(markdownTextStorage.markdown[range])
  }
}
