// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

private func useTabsToSeparateListMarker(
  _ listItem: MiniMarkdownNode
) -> [NSMutableAttributedString.Fixup] {
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

final class MarkdownFixupTextBundle {
  
  init(fileURL: URL) {
    self.textStorage = TextStorage(document: TextBundleDocument(fileURL: fileURL))
  }
  
  private let textStorage: TextStorage
  private lazy var mutableText: NSMutableAttributedString = {
    let markdown = textStorage.text.currentResult.value ?? ""
    return fixer.attributedStringWithFixups(from: markdown).mutableCopy() as! NSMutableAttributedString
  }()
  
  private lazy var fixer: MarkdownFixer = {
    var renderer = MarkdownFixer()
    renderer.fixupsForNode[.listItem] = useTabsToSeparateListMarker
    renderer.fixupsForNode[.image] = self.substituteImageAttachmentForMarkup
    return renderer
  }()

  private func substituteImageAttachmentForMarkup(
    _ imageNode: MiniMarkdownNode
  ) -> [NSMutableAttributedString.Fixup] {
    guard let imageNode = imageNode as? MiniMarkdown.Image
      else { return [] }
    let imagePath = imageNode.url.split(separator: "/").map { String($0) }
    guard let key = imagePath.last,
          let data = try? textStorage.document.data(for: key, at: Array(imagePath.dropLast())),
          let image = UIImage(data: data)
          else { return [] }
    let attachment = NSTextAttachment()
    attachment.image = image
    return [NSMutableAttributedString.Fixup(
      range: imageNode.slice.nsRange,
      newString: NSAttributedString(attachment: attachment)
    )]
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
