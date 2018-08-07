// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension NSAttributedString.Key {
  public static let markdownOriginalString = NSMutableAttributedString.Key(rawValue: "markdownOriginalString")
}

struct AttributedStringRenderer {
  
  /// Given a node, returns any changes needed to fix up an attributed string for rendering.
  typealias RenderFixupBlock = (MiniMarkdownNode) -> [NSMutableAttributedString.Change]
  
  var fixupBlocks: [NodeType : RenderFixupBlock] = [:]
  
  func renderMarkdown(_ markdown: String) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: markdown)
    let nodes = MiniMarkdown.defaultDocumentParser.parse(markdown)
    let allFixups = nodes.map({ self.fixups(for: $0) }).joined()
    attributedString.applyChanges(allFixups)
    return attributedString
  }
  
  func fixups(for node: MiniMarkdownNode) -> [NSMutableAttributedString.Change] {
    var fixups = fixupBlocks[node.type]?(node) ?? []
    let childFixups = node.children.map({ self.fixups(for: $0) }).joined()
    fixups.append(contentsOf: childFixups)
    return fixups
  }
}

extension NSAttributedString {
  var stringWithoutFixups: String {
    var changes: [RangeReplaceableChange<String>] = []
    enumerateAttribute(
      .markdownOriginalString,
      in: NSRange(location: 0, length: self.length),
      options: [.reverse]) { (originalString, range, _) in
        guard let originalString = originalString as? String else { return }
        let change = RangeReplaceableChange(range: range, newElements: originalString)
        changes.append(change)
    }
    var stringCopy = self.string
    for change in changes {
      stringCopy.applyChange(change)
    }
    return stringCopy
  }
}
