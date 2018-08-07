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
    return fixer.attributedStringWithFixups(from: markdown).mutableCopy() as! NSMutableAttributedString
  }()
  
  private let fixer: MarkdownFixer = {
    var renderer = MarkdownFixer()
    renderer.fixupsForNode[.listItem] = { (listItem) in
      if let firstWhitespaceIndex = listItem.slice.substring.firstIndex(where: { $0.isWhitespace }),
        listItem.slice.substring[firstWhitespaceIndex] != "\t" {
        let nsRange = NSRange(firstWhitespaceIndex ... firstWhitespaceIndex, in: listItem.slice.string)
        return [NSMutableAttributedString.Fixup(
          range: nsRange,
          newString: NSAttributedString(string: "\t")
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
    print("Applying change to range \(change.range)")
    mutableText.applyChange(change)
    textStorage.text.setValue(mutableText.stringWithoutFixups)
  }
}

extension NSMutableAttributedString {
  public func applyChange<C: Collection>(_ change: RangeReplaceableChange<C>) where C.Element == Character {
    self.replaceCharacters(in: change.range, with: String(change.newElements))
  }
}
