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

  public init(type: NodeType, slice: StringSlice) {
    self.type = type
    self.slice = slice
  }

  /// The type of the node
  public let type: NodeType

  /// The slice of the string covered by the node
  public let slice: StringSlice

  /// The text contents of this node. Defaults to slice.substring
  open var contents: Substring {
    return slice.substring
  }

  /// The node's children, if any.
  open var children: [Node] {
    return []
  }

  /// The parsing rules that were used to generate this node.
  public var parsingRules: ParsingRules!

  /// Some parsing rules create arrays of consecutive nodes of the same type.
  /// These can optionally be combined for a simpler data model.
  open func combining(with other: Node) -> Self? {
    return nil
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
