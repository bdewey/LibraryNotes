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
  public typealias FormattingFunction = (Node, inout NSAttributedString.Attributes) -> Void
  public typealias RenderFunction = (Node, NSAttributedString.Attributes) -> RenderedMarkdownNode

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
  private var nodes: [RenderedMarkdownNode] = []

  public var defaultAttributes = NSAttributedString.Attributes(
    UIFont.preferredFont(forTextStyle: .body)
  )

  /// The raw markdown
  public var markdown: String {
    get {
      return nodes.allText
    }
    set {
      (nodes, finalLocationPair) = nodes(for: newValue)
    }
  }

  private var finalLocationPair = LocationPair(markdown: 0, rendered: 0)

  private func nodes(
    for markdown: String
  ) -> ([RenderedMarkdownNode], LocationPair) {
    let parsedResults = parsingRules.parse(markdown)
    let nodes = parsedResults.map { render(node: $0, attributes: defaultAttributes) }
    return (nodes, computeLocationPairs(for: nodes))
  }

  private func computeLocationPairs(for nodes: [RenderedMarkdownNode]) -> LocationPair {
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
    relativeTo topLevelNode: RenderedMarkdownNode?
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
    var markdown = nodes[rangeToReplace].allText
    let nodesToReplace = nodes[rangeToReplace]
    let lowerBound = rangeToReplace.relative(to: nodes).lowerBound
    let upperBound = rangeToReplace.relative(to: nodes).upperBound
    let markdownRange = Range(
      self.markdownRange(for: range, relativeTo: nodesToReplace.first),
      in: markdown
      )!
    markdown.replaceSubrange(markdownRange, with: characters)
    let (replacementNodes, _) = nodes(for: markdown)
    let initialRendering = nodesToReplace.allRenderedResults
    let finalRendering = replacementNodes.allRenderedResults
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
      sizeChange: finalRendering.string.count - initialRendering.string.count,
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

  private func topLevelIndex(of node: RenderedMarkdownNode) -> Int {
    let root = node.root
    return nodes.firstIndex(where: { $0 === root })!
  }

  private func findNode(containing location: Int) -> RenderedMarkdownNode? {
    var currentLocation = 0
    for topLevelNode in nodes {
      for node in topLevelNode {
        let currentRange = NSRange(location: currentLocation, length: node.renderedResult.length)
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
      node.renderedResult.attributes(at: 0, effectiveRange: nil),
      NSRange(
        location: node.initialLocationPair.rendered,
        length: node.renderedResult.length
      )
    )
  }

  private func render(
    node: Node,
    attributes: NSAttributedString.Attributes
  ) -> RenderedMarkdownNode {
    var attributes = attributes
    formatters[node.type]?(node, &attributes)
    let defaultRenderFunction = node.children.isEmpty
      ? renderNode
      : { (_, _) in return RenderedMarkdownNode(type: node.type) }
    let renderFunction = renderers[node.type] ?? defaultRenderFunction
    let renderedNode = renderFunction(node, attributes)
    renderedNode.children = node.children.map { render(node: $0, attributes: attributes) }
    return renderedNode
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
    let suffix = String(self.dropFirst(prefix.count).reversed()).commonPrefix(
      with: String(other.dropFirst(prefix.count).reversed())
    )
    let lowerBound = index(startIndex, offsetBy: prefix.count)
    let upperBound = index(endIndex, offsetBy: -1 * suffix.count)
    return NSRange(lowerBound ..< upperBound, in: self)
  }
}

extension Sequence where Element == RenderedMarkdownNode {
  var allText: String {
    return self.map({ $0.allText }).reduce(into: "", { $0 += $1 })
  }

  var allRenderedResults: NSAttributedString {
    return self
      .map { $0.allRenderedResults }
      .reduce(into: NSMutableAttributedString(), { $0.append($1) })
  }

//  func diff<OtherSequence: Sequence>(
//    _ other: OtherSequence
//  ) where OtherSequence.Element == RenderedMarkdownNode {
//    let array = Array(self.joined())
//    let otherArray = Array(other.joined())
//    let prefix = array.commonPrefix(
//      with: otherArray,
//      using: { $0.type == $1.type && $0.renderedResult == $1.renderedResult }
//    )
//    let suffix = array.reversed().commonPrefix(
//      with: otherArray.reversed(),
//      using: { $0.type == $1.type && $0.renderedResult == $1.renderedResult }
//    )
//    let original = array.dropFirst(prefix.count).dropLast(suffix.count)
//    let modified = otherArray.dropFirst(prefix.count).dropLast(suffix.count)
//    if original.count == 1 && modified.count == 1 {
//      print("Can optimize!")
//    } else {
//      print("Big and slow")
//    }
//  }
}

//extension Sequence {
//  func commonPrefix<S: Sequence>(
//    with other: S,
//    using areEqual: (Element, Element) -> Bool
//  ) -> Self.SubSequence where S.Element == Element {
//    var count = 0
//    for (lhs, rhs) in zip(self, other) {
//      if areEqual(lhs, rhs) {
//        count += 1
//      } else {
//        break
//      }
//    }
//    return self.prefix(count)
//  }
//}
//
extension Array where Element == RenderedMarkdownNode {
  var allText: String { return self[0...].allText }
  var allRenderedResults: NSAttributedString { return self[0...].allRenderedResults }
}

private func renderNode(
  _ node: Node,
  with attributes: NSAttributedString.Attributes
) -> RenderedMarkdownNode {
  let text = String(node.slice.substring)
  return RenderedMarkdownNode(
    type: node.type,
    text: text,
    renderedResult: NSAttributedString(string: text, attributes: attributes.attributes)
  )
}
