// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import MobileCoreServices
import UIKit

public protocol MarkdownEditingTextViewImageStoring: AnyObject {
  /// The text view has an image to store because of a paste or drop operation.
  /// - parameter textView: The text view
  /// - parameter imageData: The image data to store
  /// - parameter suffix: Image data suffix that identifies the data format (e.g., "jpeg", "png")
  /// - returns: A string key that can locate this image later.
  func markdownEditingTextView(_ textView: MarkdownEditingTextView, store imageData: Data, suffix: String) -> String
}

/// Custom UITextView subclass that overrides "copy" to copy Markdown.
// TODO: Move renderers, MiniMarkdown text storage management, etc. to this class.
public final class MarkdownEditingTextView: UITextView {
  public override func copy(_ sender: Any?) {
    // swiftlint:disable:next force_cast
    let markdownTextStorage = textStorage as! MiniMarkdownTextStorage
    guard let range = markdownTextStorage.markdownRange(for: selectedRange) else { return }
    UIPasteboard.general.string = String(markdownTextStorage.markdown[range])
  }

  public override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
    DDLogInfo("Determining if we can paste from \(itemProviders)")
    let typeIdentifiers = pasteConfiguration!.acceptableTypeIdentifiers
    for itemProvider in itemProviders {
      for typeIdentifier in typeIdentifiers where itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
        DDLogInfo("Item provider has type \(typeIdentifier) so we can paste")
        return true
      }
    }
    return false
  }

  public override func paste(itemProviders: [NSItemProvider]) {
    DDLogInfo("Pasting \(itemProviders)")
    super.paste(itemProviders: itemProviders)
  }

  public weak var imageStorage: MarkdownEditingTextViewImageStoring?

  public override func paste(_ sender: Any?) {
    if let image = UIPasteboard.general.image, let imageStorage = self.imageStorage {
      DDLogInfo("Pasting an image")
      let imageKey: String?
      if let jpegData = UIPasteboard.general.data(forPasteboardType: kUTTypeJPEG as String) {
        DDLogInfo("Got JPEG data = \(jpegData.count) bytes")
        imageKey = imageStorage.markdownEditingTextView(self, store: jpegData, suffix: "jpeg")
      } else if let pngData = UIPasteboard.general.data(forPasteboardType: kUTTypePNG as String) {
        DDLogInfo("Got PNG data = \(pngData.count) bytes")
        imageKey = imageStorage.markdownEditingTextView(self, store: pngData, suffix: "png")
      } else if let convertedData = image.jpegData(compressionQuality: 0.8) {
        DDLogInfo("Did JPEG conversion ourselves = \(convertedData.count) bytes")
        imageKey = imageStorage.markdownEditingTextView(self, store: convertedData, suffix: "jpeg")
      } else {
        DDLogError("Could not get image data")
        imageKey = nil
      }
      if let imageKey = imageKey {
        textStorage.replaceCharacters(in: selectedRange, with: "![](\(imageKey))")
      }
    } else {
      DDLogInfo("Using superclass to paste text")
      super.paste(sender)
    }
  }

  public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)), UIPasteboard.general.image != nil {
      DDLogInfo("There's an image on the pasteboard, so allow pasting")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }
}
