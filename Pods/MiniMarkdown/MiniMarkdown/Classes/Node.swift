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

/// String identifier for the type of node.
public struct NodeType: Hashable, RawRepresentable {
  public let rawValue: String
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

/// Nodes demark parts of the input stream.
open class Node: Combinable {

  /// Extensible Key type for node properties.
  public struct Key: Hashable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public init(type: NodeType, slice: StringSlice, markdown: String = "") {
    self.type = type
    self.slice = slice
    self.markdown = markdown
  }

  /// The type of the node
  public let type: NodeType

  /// The slice of the string covered by the node.
  ///
  /// - note: If this node contains children, `slice` encompasses the markdown of all of
  ///         those nodes as well.
  public let slice: StringSlice

  /// The fragment of Markdown uniquely associated with this node.
  ///
  /// - note: If you do a pre-order traversal of the parsed nodes and concatenate all of
  ///         the `markdown` nodes together, you will have the original Markdown contents.
  public let markdown: String

  /// The markdown represented by this node and all of its children.
  public var allMarkdown: String {
    return children.reduce(into: markdown, { $0 += $1.allMarkdown })
  }

  /// Associates arbitrary properites with this node.
  public var properties: [Key: Any] = [:]

  public func getProperty<Type>(key: Key, default: () -> Type) -> Type {
    if let result = properties[key] as? Type {
      return result
    }
    let result = `default`()
    properties[key] = result
    return result
  }

  /// The text contents of this node. Defaults to slice.substring
  open var contents: Substring {
    return slice.substring
  }

  /// The node's children, if any.
  open var children: [Node] {
    return []
  }

  /// the node's parent.
  public weak var parent: Node?

  /// The root of this tree.
  /// Runs in O(depth), where depth is the depth of the Markdown hierarchy.
  internal var root: Node {
    var root = self
    while let parent = root.parent { root = parent }
    return root
  }

  /// The parsing rules that were used to generate this node.
  public var parsingRules: ParsingRules!

  /// Some parsing rules create arrays of consecutive nodes of the same type.
  /// These can optionally be combined for a simpler data model.
  open func combining(with other: Node) -> Self? {
    return nil
  }

  /// Recursively walk up the tree until we can move over one sibling.
  internal var upAndOver: Node? {
    guard let parent = parent else { return nil }
    let index = parent.children.firstIndex(where: { $0 === self })!
    if index + 1 < parent.children.endIndex { return parent.children[index + 1] }
    return parent.upAndOver
  }
}

extension Node: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      Node.self,
      children: [
        "type": type,
        "markdown": markdown,
        "properties": properties,
        "children": children,
        ]
    )
  }
}

extension Node {
  public func findNodes(where predicate: (Node) -> Bool) -> [Node] {
    var results = Array(children.map { $0.findNodes(where: predicate) }.joined())
    if predicate(self) {
      results.append(self)
    }
    return results
  }
}

/// Does a preorder traversal of the tree of nodes.
extension Node: Sequence {

  public struct Iterator: IteratorProtocol {

    /// The *next* node.
    var node: Node?

    public mutating func next() -> Node? {
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

  public func makeIterator() -> Node.Iterator {
    return Iterator(node: self)
  }
}

extension Sequence where Element == Node {
  public var allMarkdown: String {
    return self.map({ $0.allMarkdown }).reduce(into: "", { $0 += $1 })
  }
}
