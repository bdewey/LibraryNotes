// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

struct MarkdownStringRenderer {
  public typealias RenderFunction = (Node) -> String
  public var renderFunctions: [NodeType: RenderFunction] = [:]

  public func render(node: Node) -> String {
    return renderFunctions[node.type]?(node) ?? node.children.map { render(node: $0) }.joined()
  }
}
