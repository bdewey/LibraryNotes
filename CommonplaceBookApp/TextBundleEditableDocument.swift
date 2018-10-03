// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MiniMarkdown
import TextBundleKit

private let listenerKey = "org.brians-brain.CommonplaceBookApp.TextBundleDocumentListener"
private let placeholderImage = UIImage(named: "round_crop_original_black_24pt")!

extension TextBundleDocument: EditableDocument {
  public func markdownTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) -> MiniMarkdownTextStorage {
    precondition(markdownStorageListener.markdownTextStorage == nil)
    var renderers = renderers
    renderers[.image] = { (_, attributes) in
      let attachment = NSTextAttachment()
      attachment.image = placeholderImage
      attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
      return NSAttributedString(attachment: attachment)
    }
    let markdownTextStorage = MiniMarkdownTextStorage(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers,
      stylesheet: stylesheet
    )
    markdownStorageListener.markdownTextStorage = markdownTextStorage
    return markdownTextStorage
  }

  private var markdownStorageListener: DocumentTextStorageConnection {
    return listener(for: listenerKey, constructor: DocumentTextStorageConnection.init)
  }

  public var markdownTextStorage: MiniMarkdownTextStorage? {
    get {
      return markdownStorageListener.markdownTextStorage
    }
    set {
      markdownStorageListener.markdownTextStorage = newValue
    }
  }
}

private final class DocumentTextStorageConnection: NSObject,
  TextBundleDocumentSaveListener,
  NSTextStorageDelegate {

  init(document: TextBundleDocument) {
    if let text = try? TextStorage.read(from: document) {
      if let textStorage = markdownTextStorage {
        textStorage.markdown = text
      } else {
        temporaryText = text
      }
    }
  }

  private var temporaryText: String?

  var markdownTextStorage: MiniMarkdownTextStorage? {
    didSet {
      oldValue?.delegate = nil
      markdownTextStorage?.delegate = self
      if let text = temporaryText {
        markdownTextStorage?.markdown = text
        temporaryText = nil
      }
    }
  }

  var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?

  func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    guard let text = markdownTextStorage?.markdown else { return }
    try TextStorage.writeValue(text, to: textBundleDocument)
  }

  func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    guard let markdownTextStorage = markdownTextStorage,
          let markdown = try? TextStorage.read(from: textBundleDocument) else { return }
    markdownTextStorage.markdown = markdown
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    guard editedMask.contains(.editedCharacters) else { return }
    textBundleListenerHasChanges?()
  }
}
