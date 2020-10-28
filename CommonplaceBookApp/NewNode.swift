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

extension NewNodeType {
  static let documentFragment: NewNodeType = "{{fragment}}"
}

/// A key for associating values of a specific type with a node.
public protocol NodePropertyKey {
  associatedtype Value

  /// The string key used to identify the value in the property bag.
  static var key: String { get }

  /// Type-safe accessor for getting the value from the property bag.
  static func getProperty(from bag: [String: Any]?) -> Value?

  /// Type-safe setter for the value in the property bag.
  static func setProperty(_ value: Value, in bag: inout [String: Any]?)
}

/// Default implementation of getter / setter.
public extension NodePropertyKey {
  static func getProperty(from bag: [String: Any]?) -> Value? {
    guard let bag = bag else { return nil }
    if let value = bag[key] {
      return (value as! Value) // swiftlint:disable:this force_cast
    } else {
      return nil
    }
  }

  static func setProperty(_ value: Value, in bag: inout [String: Any]?) {
    if bag == nil {
      bag = [key: value]
    } else {
      bag?[key] = value
    }
  }
}

/// A node in the markup language's syntax tree.
public final class NewNode: CustomStringConvertible {
  public init(type: NewNodeType, length: Int = 0) {
    self.type = type
    self.length = length
  }

  public static func makeFragment() -> NewNode {
    return NewNode(type: .documentFragment, length: 0)
  }

  /// The type of this node.
  public var type: NewNodeType

  /// If true, this node should be considered a "fragment" (an ordered list of nodes without a root)
  public var isFragment: Bool {
    return type === NewNodeType.documentFragment
  }

  /// The length of the original text covered by this node (and all children).
  /// We only store the length so nodes can be efficiently reused while editing text, but it does mean you need to
  /// build up context (start position) by walking the parse tree.
  public var length: Int

  /// We do a couple of tree-construction optimizations that mutate existing nodes that don't "belong" to us
  private var disconnectedFromResult = false

  /// Children of this node.
  public var children = [NewNode]()

  public func appendChild(_ child: NewNode) {
    length += child.length
    if child.isFragment {
      var fragmentNodes = child.children
      if let last = children.last, let first = fragmentNodes.first, last.children.isEmpty, first.children.isEmpty, last.type == first.type {
        incrementLastChildNodeLength(by: first.length)
        fragmentNodes.removeFirst()
      }
      children.append(contentsOf: fragmentNodes)
    } else {
      // Special optimization: Adding a terminal node of the same type of the last terminal node
      // can just be a range update.
      if let lastNode = children.last, lastNode.children.isEmpty, child.children.isEmpty, lastNode.type == child.type {
        incrementLastChildNodeLength(by: child.length)
      } else {
        children.append(child)
      }
    }
  }

  private func incrementLastChildNodeLength(by length: Int) {
    guard let last = children.last else { return }
    precondition(last.children.isEmpty)
    if last.disconnectedFromResult {
      last.length += length
    } else {
      let copy = NewNode(type: last.type, length: last.length + length)
      copy.disconnectedFromResult = true
      children[children.count - 1] = copy
    }
  }

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return length == 0
  }

  public var description: String {
    "Node: \(length) \(compactStructure)"
  }

  /// Walks down the tree of nodes to find a specific node.
  public func node(at indexPath: IndexPath) -> NewNode? {
    if indexPath.isEmpty { return self }
    let nextChild = children.dropFirst(indexPath[0]).first(where: { _ in true })
    assert(nextChild != nil)
    return nextChild?.node(at: indexPath.dropFirst())
  }

  public enum NodeSearchError: Error {
    case indexOutOfRange
  }

  /// Walks down the tree and returns the leaf node that contains a specific index.
  /// - returns: The leaf node containing the index.
  /// - throws: NodeSearchError.indexOutOfRange if the index is not valid.
  public func leafNode(containing index: Int) throws -> (node: NewNode, startIndex: Int) {
    return try leafNode(containing: index, startIndex: 0)
  }

  private func leafNode(
    containing index: Int,
    startIndex: Int
  ) throws -> (node: NewNode, startIndex: Int) {
    guard index < startIndex + length else {
      throw NodeSearchError.indexOutOfRange
    }
    if children.isEmpty { return (self, startIndex) }
    var childIndex = startIndex
    for child in children {
      if index < childIndex + child.length {
        return try child.leafNode(containing: index, startIndex: childIndex)
      }
      childIndex += child.length
    }
    throw NodeSearchError.indexOutOfRange
  }

  // MARK: - Properties

  /// Lazily-allocated property bag.
  private var propertyBag: [String: Any]?

  /// Type-safe property accessor.
  public subscript<K: NodePropertyKey>(key: K.Type) -> K.Value? {
    get {
      return key.getProperty(from: propertyBag)
    }
    set {
      if let value = newValue {
        key.setProperty(value, in: &propertyBag)
      } else {
        propertyBag?.removeValue(forKey: key.key)
      }
    }
  }
}

// MARK: - Debugging support

extension NewNode {
  /// Returns the structure of this node as a compact s-expression.
  /// For example, `(document ((header text) blank_line paragraph blank_line paragraph)`
  public var compactStructure: String {
    var results = ""
    writeCompactStructure(to: &results)
    return results
  }

  /// Recursive helper for generating `compactStructure`
  private func writeCompactStructure(to buffer: inout String) {
    if children.isEmpty {
      buffer.append(type.rawValue)
    } else {
      buffer.append("(")
      buffer.append(type.rawValue)
      buffer.append(" ")
      for (index, child) in children.enumerated() {
        if index > 0 {
          buffer.append(" ")
        }
        child.writeCompactStructure(to: &buffer)
      }
      buffer.append(")")
    }
  }

  /// Returns the syntax tree and which parts of `textBuffer` the leaf nodes correspond to.
  public func debugDescription(withContentsFrom pieceTable: SafeUnicodeBuffer) -> String {
    var lines = ""
    writeDebugDescription(to: &lines, pieceTable: pieceTable, location: 0, indentLevel: 0)
    return lines
  }

  /// Recursive helper function for `debugDescription(of:)`
  private func writeDebugDescription<Target: TextOutputStream>(
    to lines: inout Target,
    pieceTable: SafeUnicodeBuffer,
    location: Int,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append(type.rawValue)
    result.append(": ")
    if children.isEmpty {
      let chars = pieceTable[NSRange(location: location, length: length)]
      let str = String(utf16CodeUnits: chars, count: chars.count)
      result.append(str.debugDescription)
    }
    lines.write(result)
    lines.write("\n")
    var childLocation = location
    for child in children {
      child.writeDebugDescription(to: &lines, pieceTable: pieceTable, location: childLocation, indentLevel: indentLevel + 1)
      childLocation += child.length
    }
  }
}
