// Copyright © 2017-present Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

/// Custom UITextView subclass that overrides "copy" to copy Markdown.
// TODO: Move renderers, MiniMarkdown text storage management, etc. to this class.
public final class MarkdownEditingTextView: UITextView {
  public override func copy(_ sender: Any?) {
    // swiftlint:disable:next force_cast
    let markdownTextStorage = textStorage as! MiniMarkdownTextStorage
    guard let range = markdownTextStorage.markdownRange(for: selectedRange) else { return }
    UIPasteboard.general.string = String(markdownTextStorage.markdown[range])
  }
}
