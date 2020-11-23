// Copyright © 2017-present Brian's Brain. All rights reserved.

import os
import MobileCoreServices
import Logging
import UIKit

private let log = OSLog(subsystem: "org.brians-brain.ScrapPaper", category: "TextView")

public protocol MarkdownEditingTextViewImageStoring: AnyObject {
  /// The text view has an image to store because of a paste or drop operation.
  /// - parameter textView: The text view
  /// - parameter imageData: The image data to store
  /// - parameter suffix: Image data suffix that identifies the data format (e.g., "jpeg", "png")
  /// - returns: A string key that can locate this image later.
  func markdownEditingTextView(_ textView: MarkdownEditingTextView, store imageData: Data, suffix: String) throws -> String
}

/// Custom UITextView subclass that overrides "copy" to copy Markdown.
// TODO: Move renderers, MiniMarkdown text storage management, etc. to this class.
public final class MarkdownEditingTextView: UITextView {
  public override func copy(_ sender: Any?) {
    // swiftlint:disable:next force_cast
    let markdownTextStorage = textStorage as! ParsedTextStorage
    let rawTextRange = markdownTextStorage.storage.rawStringRange(forRange: selectedRange)
    let characters = markdownTextStorage.storage.rawString[rawTextRange]
    UIPasteboard.general.string = String(utf16CodeUnits: characters, count: characters.count)
  }

  public override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
    Logger.shared.info("Determining if we can paste from \(itemProviders)")
    let typeIdentifiers = pasteConfiguration!.acceptableTypeIdentifiers
    for itemProvider in itemProviders {
      for typeIdentifier in typeIdentifiers where itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
        Logger.shared.info("Item provider has type \(typeIdentifier) so we can paste")
        return true
      }
    }
    return false
  }

  public override func paste(itemProviders: [NSItemProvider]) {
    Logger.shared.info("Pasting \(itemProviders)")
    super.paste(itemProviders: itemProviders)
  }

  public weak var imageStorage: MarkdownEditingTextViewImageStoring?

  public override func paste(_ sender: Any?) {
    if let image = UIPasteboard.general.image, let imageStorage = self.imageStorage {
      Logger.shared.info("Pasting an image")
      let imageKey: String?
      if let jpegData = UIPasteboard.general.data(forPasteboardType: kUTTypeJPEG as String) {
        Logger.shared.info("Got JPEG data = \(jpegData.count) bytes")
        imageKey = try? imageStorage.markdownEditingTextView(self, store: jpegData, suffix: "jpeg")
      } else if let pngData = UIPasteboard.general.data(forPasteboardType: kUTTypePNG as String) {
        Logger.shared.info("Got PNG data = \(pngData.count) bytes")
        imageKey = try? imageStorage.markdownEditingTextView(self, store: pngData, suffix: "png")
      } else if let convertedData = image.jpegData(compressionQuality: 0.8) {
        Logger.shared.info("Did JPEG conversion ourselves = \(convertedData.count) bytes")
        imageKey = try? imageStorage.markdownEditingTextView(self, store: convertedData, suffix: "jpeg")
      } else {
        Logger.shared.error("Could not get image data")
        imageKey = nil
      }
      if let imageKey = imageKey {
        textStorage.replaceCharacters(in: selectedRange, with: "![](\(imageKey))")
      }
    } else {
      Logger.shared.info("Using superclass to paste text")
      super.paste(sender)
    }
  }

  public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)), UIPasteboard.general.image != nil {
      Logger.shared.info("There's an image on the pasteboard, so allow pasting")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }

  public override func insertText(_ text: String) {
    os_signpost(.begin, log: log, name: "keystroke")
    super.insertText(text)
    os_signpost(.end, log: log, name: "keystroke")
  }
}
