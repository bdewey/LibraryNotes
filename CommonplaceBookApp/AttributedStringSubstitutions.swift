// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

// TODO: Rationalize this + fixups

struct StringNormalizer {
  
  typealias Change = RangeReplaceableChange<Substring>
  
  /// Given a node, returns an array of substitutions
  typealias SubstitutionBlock = (Node) -> [Change]
  
  var nodeSubstitutions: [NodeType : SubstitutionBlock] = [:]
  
  func normalizingChanges(for markdown: String) -> FlattenCollection<[[Change]]> {
    // TODO: Pass in parsing rules
    let nodes = ParsingRules().parse(markdown)
    let allChanges = nodes.map({ self.changes(for: $0) }).joined()
    return allChanges
  }

  func changes(for node: Node) -> [Change] {
    var allChanges = nodeSubstitutions[node.type]?(node) ?? []
    let childChanges = node.children.map({ self.changes(for: $0) }).joined()
    allChanges.append(contentsOf: childChanges)
    return allChanges
  }
}
