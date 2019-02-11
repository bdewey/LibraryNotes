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

public struct MarkdownAttributedStringRenderer {
  public init() {}
  public typealias FormattingFunction = (Node, inout AttributedStringAttributes) -> Void
  public typealias RenderFunction = (Node, AttributedStringAttributes) -> NSAttributedString
  public var formattingFunctions: [NodeType: FormattingFunction] = [:]
  public var renderFunctions: [NodeType: RenderFunction] = [:]
  public var defaultAttributes = UIFont.preferredFont(forTextStyle: .body).attributesDictionary

  public func render(
    node: Node,
    attributes: AttributedStringAttributes? = nil
  ) -> NSAttributedString {
    let result = NSMutableAttributedString()
    render(node: node, into: result, attributes: attributes ?? defaultAttributes)
    return result
  }

  private func render(
    node: Node,
    into mutableAttributedString: NSMutableAttributedString,
    attributes: AttributedStringAttributes
  ) {
    var attributes = attributes
    formattingFunctions[node.type]?(node, &attributes)
    let defaultRenderFunction: RenderFunction = { node, attributes in
      NSAttributedString(string: node.markdown, attributes: attributes)
    }
    let renderFunction = renderFunctions[node.type] ?? defaultRenderFunction
    mutableAttributedString.append(renderFunction(node, attributes))
    for child in node.children {
      render(node: child, into: mutableAttributedString, attributes: attributes)
    }
  }

  /// A renderer that returns only the text in the Markdown node
  public static let textOnly: MarkdownAttributedStringRenderer = {
    var renderer = MarkdownAttributedStringRenderer()
    renderer.renderFunctions[.text] = { node, attributes in
      NSAttributedString(string: String(node.slice.substring), attributes: attributes)
    }
    renderer.renderFunctions[.delimiter] = MarkdownAttributedStringRenderer.hidden
    renderer.renderFunctions[.hashtag] = MarkdownAttributedStringRenderer.hidden
    return renderer
  }()

  public static let hidden: RenderFunction = { _, _ in NSAttributedString() }
}

extension Array where Element == NSAttributedString {
  public func joined() -> NSAttributedString {
    let attributedString = NSMutableAttributedString()
    for element in self {
      attributedString.append(element)
    }
    return attributedString
  }
}
