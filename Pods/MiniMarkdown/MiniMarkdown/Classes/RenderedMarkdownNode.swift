//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

internal struct LocationPair {
  var markdown: Int
  var rendered: Int
}

/// A node in the tree of rendered Markdown results.
public final class RenderedMarkdownNode {

  /// Initializer.
  ///
  /// - parameter text: The fragment of Markdown associated with this node.
  /// - parameter renderedResult: How to represent this fragment as an NSAttributedString.
  public init(
    type: NodeType,
    text: String = "",
    renderedResult: NSAttributedString = NSAttributedString()
  ) {
    self.type = type
    self.text = text
    self.renderedResult = renderedResult
  }

  internal let type: NodeType

  /// The fragment of Markdown associated with this node.
  // TODO: Rename to `markdown`
  internal let text: String

  /// Representation of this Markdown fragment as an NSAttributedString.
  internal let renderedResult: NSAttributedString

  /// Our parent in the tree.
  ///
  /// For example, for this Markdown: "- This is a **great** list item!"
  /// ... "**great**" is an emphasis, contained in a paragraph, contained in a list item,
  /// contained in a list.
  internal weak var parent: RenderedMarkdownNode?

  /// Children of this node.
  internal var children: [RenderedMarkdownNode] = [] {
    didSet {
      for child in children {
        child.parent = self
      }
    }
  }

  /// The root of this tree.
  /// Runs in O(depth), where depth is the depth of the Markdown hierarchy.
  internal var root: RenderedMarkdownNode {
    var root = self
    while let parent = root.parent { root = parent }
    return root
  }

  internal private(set) var initialLocationPair = LocationPair(markdown: 0, rendered: 0)
  internal func updateInitialLocationPair(_ locationPair: LocationPair) -> LocationPair {
    var locationPair = locationPair
    initialLocationPair = locationPair
    locationPair.markdown += text.count
    locationPair.rendered += renderedResult.length
    for child in children {
      locationPair = child.updateInitialLocationPair(locationPair)
    }
    return locationPair
  }

  /// The markdown represented by this node and all of its children.
  internal var allText: String {
    return children.reduce(into: text, { $0 += $1.allText })
  }

  /// The rendered attributed string of this node and all of its children.
  internal var allRenderedResults: NSAttributedString {
    let result = NSMutableAttributedString(attributedString: renderedResult)
    return children.reduce(into: result, { $0.append($1.allRenderedResults) })
  }

  /// Recursively walk up the tree until we can move over one sibling.
  internal var upAndOver: RenderedMarkdownNode? {
    guard let parent = parent else { return nil }
    let index = parent.children.firstIndex(where: { $0 === self })!
    if index + 1 < parent.children.endIndex { return parent.children[index + 1] }
    return parent.upAndOver
  }
}

extension RenderedMarkdownNode: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      RenderedMarkdownNode.self,
      children: [
        "type": type,
        "initialLocationPair": initialLocationPair,
        "text": text,
        "renderedResult": renderedResult,
      ]
    )
  }
}

/// Does a preorder traversal of the tree of nodes.
extension RenderedMarkdownNode: Sequence {

  public struct Iterator: IteratorProtocol {

    /// The *next* node.
    var node: RenderedMarkdownNode?

    public mutating func next() -> RenderedMarkdownNode? {
      let result = node

      // Pre-order: If we have children, go to them.
      if let first = node?.children.first {
        node = first
      } else {
        // Else, return to the parent and go to the child after this one.
        node = node?.upAndOver
      }
      return result
    }
  }

  public func makeIterator() -> RenderedMarkdownNode.Iterator {
    return Iterator(node: self)
  }
}
