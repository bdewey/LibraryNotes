// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

struct MarkdownFixer {
  
  /// Given a node, returns any changes needed to fix up an attributed string for rendering.
  typealias RenderFixupBlock = (MiniMarkdownNode) -> [NSMutableAttributedString.Fixup]
  
  var fixupsForNode: [NodeType : RenderFixupBlock] = [:]
  
  func attributedStringWithFixups(from markdown: String) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: markdown)
    let nodes = MiniMarkdown.defaultDocumentParser.parse(markdown)
    let allFixups = nodes.map({ self.fixups(for: $0) }).joined()
    attributedString.performFixups(allFixups)
    return attributedString
  }
  
  func fixups(for node: MiniMarkdownNode) -> [NSMutableAttributedString.Fixup] {
    var fixups = fixupsForNode[node.type]?(node) ?? []
    let childFixups = node.children.map({ self.fixups(for: $0) }).joined()
    fixups.append(contentsOf: childFixups)
    return fixups
  }
}
