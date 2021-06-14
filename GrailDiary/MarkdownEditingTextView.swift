// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import MobileCoreServices
import os
import ParsedTextStorage
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

private let log = OSLog(subsystem: "org.brians-brain.ScrapPaper", category: "TextView")

// TODO: Move renderers, MiniMarkdown text storage management, etc. to this class.
/// Custom UITextView subclass that overrides "copy" to copy Markdown.
public final class MarkdownEditingTextView: UITextView {
  override public func copy(_ sender: Any?) {
    guard let textStorage = textStorage as? ParsedTextStorage, let parsedAttributedString = textStorage.storage as? ParsedAttributedString else {
      Logger.shared.error("Expected to get a ParsedAttributedString")
      return
    }
    let rawTextRange = parsedAttributedString.rawStringRange(forRange: selectedRange)
    let characters = parsedAttributedString.rawString[rawTextRange]
    UIPasteboard.general.string = String(utf16CodeUnits: characters, count: characters.count)
  }

  override public func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
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

  override public func paste(itemProviders: [NSItemProvider]) {
    Logger.shared.info("Pasting \(itemProviders)")
    super.paste(itemProviders: itemProviders)
  }

  public var imageStorage: ImageStorage?

  override public func paste(_ sender: Any?) {
    if let image = UIPasteboard.general.image, let imageStorage = self.imageStorage {
      Logger.shared.info("Pasting an image")
      let imageKey: String?
      if let jpegData = UIPasteboard.general.data(forPasteboardType: UTType.jpeg.identifier) {
        Logger.shared.info("Got JPEG data = \(jpegData.count) bytes")
        imageKey = try? imageStorage.storeImageData(jpegData, type: .jpeg, key: nil)
      } else if let pngData = UIPasteboard.general.data(forPasteboardType: UTType.png.identifier) {
        Logger.shared.info("Got PNG data = \(pngData.count) bytes")
        imageKey = try? imageStorage.storeImageData(pngData, type: .png, key: nil)
      } else if let convertedData = image.jpegData(compressionQuality: 0.8) {
        Logger.shared.info("Did JPEG conversion ourselves = \(convertedData.count) bytes")
        imageKey = try? imageStorage.storeImageData(convertedData, type: .jpeg, key: nil)
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

  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)), UIPasteboard.general.image != nil {
      Logger.shared.info("There's an image on the pasteboard, so allow pasting")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override public func insertText(_ text: String) {
    os_signpost(.begin, log: log, name: "keystroke")
    super.insertText(text)
    os_signpost(.end, log: log, name: "keystroke")
  }
}
