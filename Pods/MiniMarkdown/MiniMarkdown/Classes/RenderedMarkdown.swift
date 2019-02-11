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

public final class RenderedMarkdown {
  public typealias FormattingFunction = (Node, inout AttributedStringAttributes) -> Void
  public typealias RenderFunction = (Node, AttributedStringAttributes) -> NSAttributedString

  public struct ChangeDescription {
    public let changedCharacterRange: NSRange
    public let sizeChange: Int
    public let changedAttributesRange: NSRange
  }

  public init(
    parsingRules: ParsingRules,
    formatters: [NodeType: FormattingFunction],
    renderers: [NodeType: RenderFunction]
  ) {
    self.formatters = formatters
    self.renderers = renderers
    self.parsingRules = parsingRules
  }

  private let parsingRules: ParsingRules
  public let formatters: [NodeType: FormattingFunction]
  public let renderers: [NodeType: RenderFunction]

  /// The top-level nodes comprising the Markdown text.
  ///
  /// A Markdown document is a contiguous array of "blocks" (List, Paragraph, Blank, etc)
  /// and each top-level block will be a node in this array.
  internal var nodes: [Node] = []

  public var defaultAttributes = UIFont.preferredFont(forTextStyle: .body).attributesDictionary

  /// The raw markdown
  public var markdown: String {
    get {
      return nodes.allMarkdown
    }
    set {
      (nodes, finalLocationPair) = nodes(for: newValue)
    }
  }

  private var finalLocationPair = LocationPair(markdown: 0, rendered: 0)

  private func nodes(
    for markdown: String
  ) -> ([Node], LocationPair) {
    let parsedResults = parsingRules.parse(markdown)
    for node in parsedResults {
      render(node: node, attributes: defaultAttributes)
    }
    return (parsedResults, computeLocationPairs(for: parsedResults))
  }

  private func computeLocationPairs(for nodes: [Node]) -> LocationPair {
    var locationPair = LocationPair(markdown: 0, rendered: 0)
    for node in nodes {
      locationPair = node.updateInitialLocationPair(locationPair)
    }
    return locationPair
  }

  /// Returns the location in the markdown input that corresponds to a position in the rendered
  /// text.
  public func markdownLocation(for renderedLocation: Int) -> Int {
    let locationPair = findNode(containing: renderedLocation)?.initialLocationPair
      ?? finalLocationPair
    let delta = locationPair.markdown - locationPair.rendered
    return renderedLocation + delta
  }

  private func markdownRange(
    for renderedRange: NSRange,
    relativeTo topLevelNode: Node?
  ) -> NSRange {
    let markdownLocation = self.markdownLocation(for: renderedRange.location)
    let markdownMax = self.markdownLocation(for: NSMaxRange(renderedRange))
    return NSRange(
      location: markdownLocation - (topLevelNode?.initialLocationPair.markdown ?? 0),
      length: markdownMax - markdownLocation
    )
  }

  private func replaceTextInTopLevelNodes<R: RangeExpression>(
    nodeRange rangeToReplace: R,
    textRange range: NSRange,
    replacementText characters: String
  ) -> ChangeDescription where R.Bound == Int {
    var markdown = nodes[rangeToReplace].allMarkdown
    let nodesToReplace = nodes[rangeToReplace]
    let lowerBound = rangeToReplace.relative(to: nodes).lowerBound
    let upperBound = rangeToReplace.relative(to: nodes).upperBound
    let markdownRange = Range(
      self.markdownRange(for: range, relativeTo: nodesToReplace.first),
      in: markdown
    )!
    markdown.replaceSubrange(markdownRange, with: characters)
    let (replacementNodes, _) = nodes(for: markdown)
    assert(
      replacementNodes.allMarkdown == markdown,
      "Parsed Markdown is not consistent with original Markdown"
    )
    let initialRendering = nodesToReplace.joined().allRenderedResults
    let finalRendering = replacementNodes.joined().allRenderedResults
    let changedRange = initialRendering.string.changedRange(
      from: finalRendering.string
    )
    let firstNodeAfterReplacementRange = upperBound < nodes.endIndex
      ? nodes[upperBound]
      : nil
    nodes.replaceSubrange(rangeToReplace, with: replacementNodes)
    finalLocationPair = computeLocationPairs(for: nodes)
    let initialRenderedLocation = lowerBound < nodes.endIndex
      ? nodes[lowerBound].initialLocationPair.rendered
      : 0
    let finalRenderedLocation = firstNodeAfterReplacementRange?.initialLocationPair.rendered
      ?? finalLocationPair.rendered
    return ChangeDescription(
      changedCharacterRange: changedRange.offset(by: initialRenderedLocation),
      sizeChange: finalRendering.string.utf16.count - initialRendering.string.utf16.count,
      changedAttributesRange: NSRange(
        location: initialRenderedLocation,
        length: finalRenderedLocation - initialRenderedLocation
      )
    )
  }

  public func replaceCharacters(in range: NSRange, with characters: String) -> ChangeDescription {
    if let first = findNode(containing: range.location) {
      // We're doing actual replacement.
      let last = findNode(containing: NSMaxRange(range)) ?? nodes.last!
      let rangeToReplace = topLevelIndex(of: first) ... topLevelIndex(of: last)
      return replaceTextInTopLevelNodes(
        nodeRange: rangeToReplace,
        textRange: range,
        replacementText: characters
      )
    } else {
      // We're appending text to the end.
      if nodes.last != nil {
        return replaceTextInTopLevelNodes(
          nodeRange: nodes.endIndex - 1 ..< nodes.endIndex,
          textRange: range,
          replacementText: characters
        )
      } else {
        return replaceTextInTopLevelNodes(
          nodeRange: nodes.startIndex ..< nodes.endIndex,
          textRange: range,
          replacementText: characters
        )
      }
    }
  }

  private func topLevelIndex(of node: Node) -> Int {
    let root = node.root
    return nodes.firstIndex(where: { $0 === root })!
  }

  internal func findNode(containing location: Int) -> Node? {
    var currentLocation = 0
    for topLevelNode in nodes {
      for node in topLevelNode {
        let currentRange = NSRange(location: currentLocation, length: node.attributedString.length)
        if currentRange.contains(location) {
          return node
        }
        currentLocation = NSMaxRange(currentRange)
      }
    }
    return nil
  }

  public func attributesAndRange(at location: Int) -> ([NSAttributedString.Key: Any], NSRange) {
    guard let node = findNode(containing: location) else {
      return ([:], NSRange(location: location, length: 0))
    }
    return (
      node.attributedString.attributes(at: 0, effectiveRange: nil),
      NSRange(
        location: node.initialLocationPair.rendered,
        length: node.attributedString.length
      )
    )
  }

  private func render(
    node: Node,
    attributes: AttributedStringAttributes
  ) {
    var attributes = attributes
    formatters[node.type]?(node, &attributes)
    let defaultRenderFunction: RenderFunction = { node, attributes in
      NSAttributedString(string: node.markdown, attributes: attributes)
    }
    let renderFunction = renderers[node.type] ?? defaultRenderFunction
    node.attributedString = renderFunction(node, attributes)
    for child in node.children {
      render(node: child, attributes: attributes)
    }
  }

  /// The rendered string
  public var attributedString: NSAttributedString {
    return nodes.reduce(into: NSMutableAttributedString(), { $0.append($1.allRenderedResults) })
  }
}

extension NSRange {
  public func offset(by amount: Int) -> NSRange {
    return NSRange(location: location + amount, length: length)
  }
}

extension StringProtocol where SubSequence == Substring {
  func changedRange<S: StringProtocol>(from other: S) -> NSRange {
    let prefix = commonPrefix(with: other)
    let suffix = String(dropFirst(prefix.count).reversed()).commonPrefix(
      with: String(other.dropFirst(prefix.count).reversed())
    )
    let lowerBound = index(startIndex, offsetBy: prefix.count)
    let upperBound = index(endIndex, offsetBy: -1 * suffix.count)
    return NSRange(lowerBound ..< upperBound, in: self)
  }
}

extension Sequence where Element == Node {
  var allRenderedResults: NSAttributedString {
    return map { $0.attributedString }
      .reduce(into: NSMutableAttributedString(), { $0.append($1) })
  }
}
