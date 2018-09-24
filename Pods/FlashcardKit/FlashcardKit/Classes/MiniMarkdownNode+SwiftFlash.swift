// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension Node {
  /// Finds the complete "node path" to blocks that match the predictate.
  ///
  /// The node path is an array of integers, where each integer is an index into the child
  /// array of the node.
  public func findNodePaths(toBlocksMatching predicate: (Node) -> Bool) -> [[Int]] {
    var results: [[Int]] = []
    let children = self.children
    for i in 0 ..< children.count {
      for childPath in children[i].findNodePaths(toBlocksMatching: predicate) {
        var path = childPath
        path.insert(i, at: 0)
        results.append(path)
      }
    }
    if predicate(self) {
      results.append([])
    }
    return results
  }

  public func findFirstChild<PathType: Collection>(
    on nodePath: PathType,
    where predicate: (Node) -> Bool
  ) -> Node? where PathType.Element == Int {
    if predicate(self) { return self }
    if let childIndex = nodePath.first {
      return children[childIndex].findFirstChild(on: nodePath.dropFirst(), where: predicate)
    } else {
      return nil
    }
  }

  public func walkNodePath(_ path: [Int], block: (Node) -> Void) {
    var currentNode: Node = self
    block(currentNode)
    for childIndex in path {
      currentNode = currentNode.children[childIndex]
      block(currentNode)
    }
  }
}
