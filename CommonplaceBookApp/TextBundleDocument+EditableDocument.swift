// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import textbundle_swift

final class MarkdownFixupTextBundle {
  
  init(fileURL: URL) {
    self.textStorage = TextStorage(document: TextBundleDocument(fileURL: fileURL))
  }
  
  private let textStorage: TextStorage
  private lazy var mutableText: NSMutableAttributedString = {
    let markdown = (try? textStorage.text.value()) ?? ""
    return renderer.renderMarkdown(markdown).mutableCopy() as! NSMutableAttributedString
  }()
  
  private let renderer: AttributedStringRenderer = {
    var renderer = AttributedStringRenderer()
    renderer.fixupBlocks[.listItem] = { (listItem) in
      if let firstWhitespaceIndex = listItem.slice.substring.firstIndex(where: { $0.isWhitespace }),
        listItem.slice.substring[firstWhitespaceIndex] != "\t" {
        let nsRange = NSRange(firstWhitespaceIndex ... firstWhitespaceIndex, in: listItem.slice.string)
        let originalString = String(listItem.slice.string[firstWhitespaceIndex...firstWhitespaceIndex])
        return [NSMutableAttributedString.Change(
          range: nsRange,
          newString: NSAttributedString(
            string: "\t",
            attributes: [.markdownOriginalString: originalString]
          )
          )]
      }
      return []
    }
    return renderer
  }()
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
  
  public func applyChange(_ change: StringChange) {
    mutableText.applyChange(change)
    textStorage.text.setValue(mutableText.stringWithoutFixups)
  }
}
