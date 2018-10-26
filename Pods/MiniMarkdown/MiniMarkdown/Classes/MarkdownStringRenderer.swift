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

/// Converts a Markdown node into a string.
public struct MarkdownStringRenderer {

  /// A function that turns a node into a string.
  public typealias RenderFunction = (Node) -> String

  public init() { }

  /// Maps node types to render functions.
  public var renderFunctions: [NodeType: RenderFunction] = [:]

  /// Converts a node into a string.
  ///
  /// - note: If there is a render function for `node.type`, then this method calls that function.
  ///         Otherwise, it calls `render(node:)` on each of this node's children.
  public func render(node: Node) -> String {
    return renderFunctions[node.type]?(node) ?? node.children.map { render(node: $0) }.joined()
  }

  /// A renderer that returns only the text in the Markdown node
  public static let textOnly: MarkdownStringRenderer = {
    var renderer = MarkdownStringRenderer()
    renderer.renderFunctions[.text] = { return String($0.slice.substring) }
    return renderer
  }()
}
