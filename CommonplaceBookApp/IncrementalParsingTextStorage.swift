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

#if !os(macOS)
  import UIKit
#else
  import AppKit
#endif

import Logging

private let logger = Logger(label: "IncrementalParsingTextStorage")

/// Just a handy alias for NSAttributedString attributes
public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]

/// A function that modifies NSAttributedString attributes based the syntax tree.
public typealias FormattingFunction = (NewNode, inout AttributedStringAttributes) -> Void

/// A function that overlays replacements...
public typealias ReplacementFunction = (NewNode, Int) -> [unichar]?

/// Uses an `IncrementalParsingBuffer` to implement `NSTextStorage`.
public final class IncrementalParsingTextStorage: NSTextStorage {
  public struct Settings {
    var grammar: PackratGrammar
    var defaultAttributes: AttributedStringAttributes
    var formattingFunctions: [NewNodeType: FormattingFunction]
    var replacementFunctions: [NewNodeType: ReplacementFunction]
  }

  public convenience init(string: String, settings: Settings) {
    self.init(
      string: string,
      grammar: settings.grammar,
      defaultAttributes: settings.defaultAttributes,
      formattingFunctions: settings.formattingFunctions,
      replacementFunctions: settings.replacementFunctions
    )
  }

  public init(
    string: String = "",
    grammar: PackratGrammar,
    defaultAttributes: AttributedStringAttributes,
    formattingFunctions: [NewNodeType: FormattingFunction],
    replacementFunctions: [NewNodeType: ReplacementFunction]
  ) {
    self.defaultAttributes = defaultAttributes
    self.formattingFunctions = formattingFunctions
    self.replacementFunctions = replacementFunctions
    self.buffer = IncrementalParsingBuffer(string, grammar: grammar)
    self.memoizedString = PieceTableString(pieceTable: PieceTable(buffer.text))
    super.init()
    var range: Range<Int>?
    if case .success(let node) = buffer.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        leafNodeRange: &range
      )
      applyReplacements(in: node, startingIndex: 0, to: memoizedString)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  #if os(macOS)
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
      fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
  #endif

  // MARK: - Stored properties

  public let buffer: IncrementalParsingBuffer
  private let defaultAttributes: AttributedStringAttributes
  private let formattingFunctions: [NewNodeType: FormattingFunction]
  private let replacementFunctions: [NewNodeType: ReplacementFunction]

  // MARK: - Public

  private let memoizedString: PieceTableString

  /// The character contents as a single String value.
  // TODO: Memoize
  public override var string: String {
    return memoizedString as String
  }

  /// The character contents as a single String value without any text replacements applied.
  public var rawText: String {
    get {
      buffer.text as String
    }
    set {
      replaceCharacters(in: NSRange(location: 0, length: buffer.count), with: newValue)
    }
  }

  public func rawTextRange(forVisibleRange visibleNSRange: NSRange) -> NSRange {
    let range = Range(visibleNSRange, in: memoizedString.pieceTable)!
    let lowerBound = memoizedString.pieceTable.findOriginalBound(.lowerBound, forBound: range.lowerBound)
    let upperBound = memoizedString.pieceTable.findOriginalBound(.upperBound, forBound: range.upperBound)
    assert(upperBound >= lowerBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  public func visibleTextRange(forRawRange rawNSRange: NSRange) -> NSRange {
    let lowerBound = memoizedString.pieceTable.findBound(.lowerBound, forOriginalBound: rawNSRange.lowerBound)
    let upperBound = memoizedString.pieceTable.findBound(.upperBound, forOriginalBound: rawNSRange.upperBound)
    return NSRange(lowerBound ..< upperBound, in: memoizedString.pieceTable)
  }

  /// Gets a subset of the available characters in storage.
  public subscript(range: NSRange) -> [unichar] { buffer[range] }

  /// Returns the path through the syntax tree to the leaf node that contains `index`.
  /// - returns: An array of nodes where the first element is the root, and each subsequent node descends one level to the leaf.
  public func path(to index: Int) -> [AnchoredNode] { buffer.path(to: index) }

  private func applyReplacements(in node: NewNode, startingIndex: Int, to string: NSMutableString) {
    guard node.hasTextReplacement else { return }
    if let replacement = node.textReplacement {
      string.replaceCharacters(in: NSRange(location: startingIndex, length: node.length), with: String(utf16CodeUnits: replacement, count: replacement.count))
    }
    for (child, index) in node.childrenAndOffsets(startingAt: startingIndex).reversed() {
      applyReplacements(in: child, startingIndex: index, to: string)
    }
  }

  /// Replaces the characters in the given range with the characters of the given string.
  public override func replaceCharacters(in range: NSRange, with str: String) {
    var changedAttributesRange: Range<Int>?
    let lengthBeforeChanges = memoizedString.length
    beginEditing()
    let bufferRange = rawTextRange(forVisibleRange: range)
    buffer.replaceCharacters(
      in: bufferRange,
      with: str
    )
    memoizedString.revertToOriginal()
    if case .success(let node) = buffer.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        leafNodeRange: &changedAttributesRange
      )
      applyReplacements(in: node, startingIndex: 0, to: memoizedString)
    }
    // Deliver delegate messages
    // Because the edit may change the parse tree, `finalEditedRange` might not be the same as `range`
    let finalEditedRange = visibleTextRange(forRawRange: bufferRange)
    edited([.editedCharacters], range: range, changeInLength: memoizedString.length - lengthBeforeChanges)
    logger.debug("Edit \(range) change in length \(str.utf16.count - finalEditedRange.length)")
    if let range = changedAttributesRange {
      edited([.editedAttributes], range: visibleTextRange(forRawRange: NSRange(range)), changeInLength: 0)
      logger.debug("Changed attributes at \(visibleTextRange(forRawRange: NSRange(range)))")
    }
    endEditing()
  }

  /// Returns the attributes for the character at a given index.
  /// - Parameters:
  ///   - location: The index for which to return attributes. This value must lie within the bounds of the receiver.
  ///   - range: Upon return, the range over which the attributes and values are the same as those at index. This range isn’t necessarily the maximum range covered, and its extent is implementation-dependent.
  /// - Returns: The attributes for the character at index.
  public override func attributes(
    at location: Int,
    effectiveRange range: NSRangePointer?
  ) -> [NSAttributedString.Key: Any] {
    guard let tree = try? buffer.result.get() else {
      range?.pointee = NSRange(location: 0, length: buffer.count)
      return defaultAttributes
    }
    var bufferLocation = rawTextRange(forVisibleRange: NSRange(location: location, length: 0)).location
    repeat {
    // Crash on invalid location or if I didn't set attributes (shouldn't happen?)
      let leafNode = try! tree.leafNode(containing: bufferLocation) // swiftlint:disable:this force_try
      let visibleRange = visibleTextRange(forRawRange: leafNode.range)
      if visibleRange.length > 0 {
        assert(visibleRange.contains(location))
        range?.pointee = visibleRange
        logger.debug("Found attributes at location \(bufferLocation) for range \(visibleRange) (\(visibleRange.upperBound)), length = \(length)")
        return leafNode.node.attributedStringAttributes!
      } else {
        // We landed on a node that isn't visible in the final result. Skip to the next node.
        bufferLocation += leafNode.node.length
      }
    } while true
  }

  /// Sets the attributes for the characters in the specified range to the specified attributes.
  /// - Parameters:
  ///   - attrs: A dictionary containing the attributes to set.
  ///   - range: The range of characters whose attributes are set.
  public override func setAttributes(
    _ attrs: [NSAttributedString.Key: Any]?,
    range: NSRange
  ) {
    // TODO. Maybe just ignore? But this is how emojis and misspellings get formatted
    // by the system.
  }

  // MARK: - Private

  /// Associates AttributedStringAttributes with this part of the syntax tree.
  func applyAttributes(
    to node: NewNode,
    attributes: AttributedStringAttributes,
    startingIndex: Int,
    leafNodeRange: inout Range<Int>?
  ) {
    // If we already have attributes we don't need to do anything else.
    guard node[NodeAttributesKey.self] == nil else {
      return
    }
    var attributes = attributes
    formattingFunctions[node.type]?(node, &attributes)
    if let replacementFunction = replacementFunctions[node.type], let textReplacement = replacementFunction(node, startingIndex) {
      node.textReplacement = textReplacement
      node.hasTextReplacement = true
      node.textReplacementChangeInLength = textReplacement.count - node.length
     } else {
      node.hasTextReplacement = false
    }
    node.attributedStringAttributes = attributes
    var childLength = 0
    if node.children.isEmpty {
      // We are a leaf. Adjust leafNodeRange.
      let lowerBound = Swift.min(startingIndex, leafNodeRange?.lowerBound ?? Int.max)
      let upperBound = Swift.max(startingIndex + node.length, leafNodeRange?.upperBound ?? Int.min)
      leafNodeRange = lowerBound ..< upperBound
    }
    var childTextReplacementChangeInLength = 0
    for child in node.children {
      applyAttributes(
        to: child,
        attributes: attributes,
        startingIndex: startingIndex + childLength,
        leafNodeRange: &leafNodeRange
      )
      childLength += child.length
      childTextReplacementChangeInLength += child.textReplacementChangeInLength
      node.hasTextReplacement = node.hasTextReplacement || child.hasTextReplacement
    }
    node.textReplacementChangeInLength += childTextReplacementChangeInLength
  }
}

// MARK: - Stylesheets
// TODO: Move this to a separate file?

public extension IncrementalParsingTextStorage.Settings {
  static func plainText(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
    extraAttributes: [NSAttributedString.Key: Any] = [:]
  ) -> IncrementalParsingTextStorage.Settings {
    var formattingFunctions = [NewNodeType: FormattingFunction]()
    var replacementFunctions = [NewNodeType: ReplacementFunction]()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.strongEmphasis] = { $1.bold = true }
    formattingFunctions[.code] = { $1.familyName = "Menlo" }
    replacementFunctions[.delimiter] = { _, _ in [] }
    replacementFunctions[.clozeHint] = { _, _ in [] }
    var defaultAttributes: AttributedStringAttributes = [
      .font: UIFont.preferredFont(forTextStyle: textStyle),
      .foregroundColor: textColor,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.merge(extraAttributes, uniquingKeysWith: { _, new in new })
    return IncrementalParsingTextStorage.Settings(
      grammar: MiniMarkdownGrammar.shared,
      defaultAttributes: defaultAttributes,
      formattingFunctions: formattingFunctions,
      replacementFunctions: replacementFunctions
    )
  }
}

/// Key for storing the string attributes associated with a node.
private struct NodeAttributesKey: NodePropertyKey {
  typealias Value = AttributedStringAttributes

  static let key = "attributes"
}

private struct NodeTextReplacementKey: NodePropertyKey {
  typealias Value = [unichar]
  static let key = "textReplacement"
}

private struct NodeHasTextReplacementKey: NodePropertyKey {
  typealias Value = Bool
  static let key = "hasTextReplacement"
}

private struct NodeTextReplacementChangeInLengthKey: NodePropertyKey {
  typealias Value = Int
  static let key = "textReplacementChangeInLength"
}

private extension NewNode {
  /// The attributes associated with this node, if set.
  var attributedStringAttributes: AttributedStringAttributes? {
    get {
      self[NodeAttributesKey.self]
    }
    set {
      self[NodeAttributesKey.self] = newValue
    }
  }

  var textReplacement: [unichar]? {
    get {
      self[NodeTextReplacementKey.self]
    }
    set {
      self[NodeTextReplacementKey.self] = newValue
    }
  }

  var hasTextReplacement: Bool {
    get {
      self[NodeHasTextReplacementKey.self] ?? false
    }
    set {
      self[NodeHasTextReplacementKey.self] = newValue
    }
  }

  var textReplacementChangeInLength: Int {
    get {
      self[NodeTextReplacementChangeInLengthKey.self] ?? 0
    }
    set {
      self[NodeTextReplacementChangeInLengthKey.self] = newValue
    }
  }

  func changeInLengthBeforeOffset(
    _ offset: Int,
    favorLowerBound: Bool
  ) -> Int {
    assert(offset >= 0)
    guard hasTextReplacement else { return 0 }
    if offset >= length { return textReplacementChangeInLength }
    if children.isEmpty {
      if favorLowerBound {
        return 0
      } else {
        return textReplacementChangeInLength
      }
    }
    var childOffset = 0
    var changeInLength = 0
    for child in children {
      if childOffset >= offset { break }
      changeInLength += child.changeInLengthBeforeOffset(offset - childOffset, favorLowerBound: favorLowerBound)
      childOffset += child.length
    }
    return changeInLength
  }

  func rangeBeforeReplacements(_ range: Range<Int>) -> Range<Int> {
    let lowerBound = range.lowerBound - changeInLengthBeforeOffset(range.lowerBound, favorLowerBound: true)
    let upperBound = range.upperBound - changeInLengthBeforeOffset(range.upperBound, favorLowerBound: false)
    return lowerBound ..< upperBound
  }

  func rangeAfterReplacements(_ range: Range<Int>) -> Range<Int> {
    let lowerBound = range.lowerBound + changeInLengthBeforeOffset(range.lowerBound, favorLowerBound: true)
    let upperBound = range.upperBound + changeInLengthBeforeOffset(range.upperBound, favorLowerBound: false)
    return lowerBound ..< upperBound
  }

  func childrenAndOffsets(startingAt offset: Int) -> [(child: NewNode, offset: Int)] {
    var offset = offset
    var results = [(child: NewNode, offset: Int)]()
    for child in children {
      results.append((child: child, offset: offset))
      offset += child.length
    }
    return results
  }
}