// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

struct StringNormalizer {
  
  typealias Change = RangeReplaceableChange<Substring>
  
  /// Given a node, returns an array of substitutions
  typealias SubstitutionBlock = (MiniMarkdownNode) -> [Change]
  
  var nodeSubstitutions: [NodeType : SubstitutionBlock] = [:]
  
  func normalizingChanges(for markdown: String) -> FlattenCollection<[[Change]]> {
    let nodes = MiniMarkdown.defaultDocumentParser.parse(markdown)
    let allChanges = nodes.map({ self.changes(for: $0) }).joined()
    return allChanges
  }

  func changes(for node: MiniMarkdownNode) -> [Change] {
    var allChanges = nodeSubstitutions[node.type]?(node) ?? []
    let childChanges = node.children.map({ self.changes(for: $0) }).joined()
    allChanges.append(contentsOf: childChanges)
    return allChanges
  }
}
