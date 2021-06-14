// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import ObjectiveCTextStorageWrapper
import os
import UIKit

private let log = OSLog(subsystem: "org.brians-brain.GrailDiary", category: "ParsedAttributedString")

/// A quick format function can change *only* string attributes based *only* on the type of syntax tree node, but it can do it with simpler syntax than FullFormatFunction.
public typealias QuickFormatFunction = (SyntaxTreeNode, inout AttributedStringAttributesDescriptor) -> Void

/// A function can change both formatting *and* the actual string characters that represent a part of the syntax tree. It also gets to examine the actual text as opposed to
/// just knowing the type.
public typealias FullFormatFunction = (SyntaxTreeNode, Int, SafeUnicodeBuffer, inout AttributedStringAttributesDescriptor) -> [unichar]?

private extension Logging.Logger {
  static let attributedStringLogger: Logging.Logger = {
    var logger = Logger(label: "org.brians-brain.ParsedAttributedString")
    logger.logLevel = .info
    return logger
  }()
}

/// An NSMutableAttributedString subclass that:
///
/// 1. Parses its contents based upon the rules of `grammar`
/// 2. Determines the attributes and final contents of the string by applying `formattingFunctions` and `replacementFunctions` to the abstract syntax tree.
///
/// `formattingFunctions` are fairly straightforward. These are functions that have an opportunity to modify the current string attributes for each node in the abstract syntax tree. The attributes will apply to all characters covered by that node.
/// `replacementFunctions` are a little more complicated. They give an opportunity to *alter the actual string* based upon the nodes of the abstract syntax tree. For example, you can use replacement functions to hide the delimiters in Markdown text, or to replace spaces with tabs.
///
/// The `string` property contains the contents **after**  applying replacements. The `rawString` property contains the contents **before** applying replacements. Importantly, the `rawString` is what gets *parsed* in order to determine `string`. However, when calling `replaceCharacters(in:with:)`, the range is relative to the characters in `string`. The methods `rawStringRange(forRange:)` and `range(forRawStringRange:)` convert ranges between `string` and `rawString`
@objc public final class ParsedAttributedString: WrappableTextStorage {
  public struct Settings {
    public init(grammar: PackratGrammar, defaultAttributes: AttributedStringAttributesDescriptor, quickFormatFunctions: [SyntaxTreeNodeType: QuickFormatFunction], fullFormatFunctions: [SyntaxTreeNodeType: FullFormatFunction]) {
      self.grammar = grammar
      self.defaultAttributes = defaultAttributes
      self.quickFormatFunctions = quickFormatFunctions
      self.fullFormatFunctions = fullFormatFunctions
    }

    public var grammar: PackratGrammar
    public var defaultAttributes: AttributedStringAttributesDescriptor
    public var quickFormatFunctions: [SyntaxTreeNodeType: QuickFormatFunction]
    public var fullFormatFunctions: [SyntaxTreeNodeType: FullFormatFunction]
  }

  public convenience init(string: String, settings: Settings) {
    self.init(
      string: string,
      grammar: settings.grammar,
      defaultAttributes: settings.defaultAttributes,
      quickFormatFunctions: settings.quickFormatFunctions,
      fullFormatFunctions: settings.fullFormatFunctions
    )
  }

  override public convenience init() {
    assertionFailure("Are you sure you want a plain-text attributed string?")
    self.init(
      grammar: PlainTextGrammar(),
      defaultAttributes: AttributedStringAttributesDescriptor(textStyle: .body, color: .label),
      quickFormatFunctions: [:],
      fullFormatFunctions: [:]
    )
  }

  public init(
    string: String = "",
    grammar: PackratGrammar,
    defaultAttributes: AttributedStringAttributesDescriptor,
    quickFormatFunctions: [SyntaxTreeNodeType: QuickFormatFunction],
    fullFormatFunctions: [SyntaxTreeNodeType: FullFormatFunction]
  ) {
    self.defaultAttributes = defaultAttributes
    self.formattingFunctions = quickFormatFunctions
    self.replacementFunctions = fullFormatFunctions
    self.rawString = ParsedString(string, grammar: grammar)
    self._string = PieceTableString(pieceTable: PieceTable(rawString.text))
    self.attributesArray = AttributesArray(attributesCache: attributesCache)
    super.init()
    if case .success(let node) = rawString.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        resultingAttributesArray: &attributesArray
      )
      applyReplacements(in: node, startingIndex: 0, to: _string)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Stored properties

  /// The "raw" contents of the string. This is what is parsed, and determines what replacements get applied to determine the final contents.
  public let rawString: ParsedString

  /// The underlying NSString that backs `string`. This is public and exposed to Objective-C to allow O(1) access to the string contents from TextKit.
  @objc public let _string: PieceTableString // swiftlint:disable:this identifier_name

  /// The contents of the string. This is derived from `rawString` after applying replacements.
  override public var string: String { _string as String }

  /// Default attributes
  private let defaultAttributes: AttributedStringAttributesDescriptor

  private var attributesArray: AttributesArray

  /// A set of functions that customize attributes based upon the nodes in the AST.
  private let formattingFunctions: [SyntaxTreeNodeType: QuickFormatFunction]

  /// A set of functions that replace the contents of `rawString` -- e.g., these can be used to remove delimiters or change spaces to tabs.
  private let replacementFunctions: [SyntaxTreeNodeType: FullFormatFunction]

  /// Caches a mapping from descriptor to actual attributes for the lifetime of this ParsedAttributedString
  private let attributesCache = AttributesCache()

  /// Given a range in `string`, computes the equivalent range in `rawString`
  /// - note: Characters from a "replacement" are an atomic unit. If the input range overlaps with part of the characters in a replacement, the resulting range will encompass the entire replacement.
  public func rawStringRange(forRange visibleNSRange: NSRange) -> NSRange {
    let range = Range(visibleNSRange, in: _string.pieceTable)!
    let lowerBound = _string.pieceTable.findOriginalBound(.lowerBound, forBound: range.lowerBound)
    let upperBound = _string.pieceTable.findOriginalBound(.upperBound, forBound: range.upperBound)
    assert(upperBound >= lowerBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  /// Given a range in `rawString`, computes the equivalent range in `string`
  /// - note: Characters from a "replacement" are an atomic unit. If the input range overlaps with part of the characters in a replacement, the resulting range will encompass the entire replacement.
  public func range(forRawStringRange rawNSRange: NSRange) -> NSRange {
    let lowerBound = _string.pieceTable.findBound(.lowerBound, forOriginalBound: rawNSRange.lowerBound)
    let upperBound = _string.pieceTable.findBound(.upperBound, forOriginalBound: rawNSRange.upperBound)
    return NSRange(lowerBound ..< upperBound, in: _string.pieceTable)
  }

  /// Gets a subset of the available characters in storage.
  public subscript(range: NSRange) -> [unichar] { rawString[range] }

  /// Returns the path through the syntax tree to the leaf node that contains `index`.
  /// - returns: An array of nodes where the first element is the root, and each subsequent node descends one level to the leaf.
  public func path(to index: Int) -> [AnchoredNode] {
    let bufferRange = rawStringRange(forRange: NSRange(location: index, length: 0))
    return rawString.path(to: bufferRange.location)
  }

  /// Replaces the characters in the given range with the characters of the given string.
  override public func replaceCharacters(in range: NSRange, with str: String) {
    let lengthBeforeChanges = _string.length
    let bufferRange = rawStringRange(forRange: range)
    rawString.replaceCharacters(
      in: bufferRange,
      with: str
    )
    _string.revertToOriginal()
    var newAttributes = AttributesArray(attributesCache: attributesCache)
    if case .success(let node) = rawString.result {
      os_signpost(.begin, log: log, name: "applyAttributes")
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        resultingAttributesArray: &newAttributes
      )
      os_signpost(.end, log: log, name: "applyAttributes")
      applyReplacements(in: node, startingIndex: 0, to: _string)
    } else {
      newAttributes = attributesArray
    }
    // Deliver delegate messages
    Logger.attributedStringLogger.debug("Edit \(range) change in length \(_string.length - lengthBeforeChanges)")
    attributesArray.adjustLengthOfRun(at: range.location, by: _string.length - lengthBeforeChanges, defaultAttributes: defaultAttributes)
    // swiftlint:disable:next force_try
    let changedAttributesRange = (try! attributesArray.rangeOfAttributeDifferences(from: newAttributes)) ?? NSRange(location: range.location, length: 0)
    attributesArray = newAttributes
    delegate?.attributedStringDidChange(
      withOldRange: range,
      changeInLength: _string.length - lengthBeforeChanges,
      changedAttributesRange: changedAttributesRange
    )
  }

  /// Returns the attributes for the character at a given index.
  /// - Parameters:
  ///   - location: The index for which to return attributes. This value must lie within the bounds of the receiver.
  ///   - range: Upon return, the range over which the attributes and values are the same as those at index. This range isn’t necessarily the maximum range covered, and its extent is implementation-dependent.
  /// - Returns: The attributes for the character at index.
  override public func attributes(
    at location: Int,
    effectiveRange range: NSRangePointer?
  ) -> [NSAttributedString.Key: Any] {
    return attributesArray.attributes(at: location, effectiveRange: range)
  }

  /// Sets the attributes for the characters in the specified range to the specified attributes.
  /// - Parameters:
  ///   - attrs: A dictionary containing the attributes to set.
  ///   - range: The range of characters whose attributes are set.
  override public func setAttributes(
    _ attrs: [NSAttributedString.Key: Any]?,
    range: NSRange
  ) {
    // IGNORE -- we do syntax highlighting
  }
}

// MARK: - Private

private extension ParsedAttributedString {
  /// Associates AttributedStringAttributes with this part of the syntax tree.
  func applyAttributes(
    to node: SyntaxTreeNode,
    attributes: AttributedStringAttributesDescriptor,
    startingIndex: Int,
    resultingAttributesArray: inout AttributesArray
  ) {
    var attributes = attributes
    let initialAttributesArrayCount = resultingAttributesArray.count
    if let precomputedAttributes = node.attributedStringAttributes {
      attributes = precomputedAttributes
    } else {
      formattingFunctions[node.type]?(node, &attributes)
      if let replacementFunction = replacementFunctions[node.type],
         let textReplacement = replacementFunction(node, startingIndex, rawString, &attributes)
      {
        node.textReplacement = textReplacement
        node.hasTextReplacement = true
        node.textReplacementChangeInLength = textReplacement.count - node.length
      } else {
        node.hasTextReplacement = false
      }
      node.attributedStringAttributes = attributes
    }
    var childLength = 0
    if node.children.isEmpty || node.textReplacement != nil {
      // We are a leaf. Adjust leafNodeRange.
      resultingAttributesArray.appendAttributes(attributes, length: node.length + node.textReplacementChangeInLength)
    }
    if node.textReplacement != nil {
      return
    }
    var childTextReplacementChangeInLength = 0
    for child in node.children {
      applyAttributes(
        to: child,
        attributes: attributes,
        startingIndex: startingIndex + childLength,
        resultingAttributesArray: &resultingAttributesArray
      )
      childLength += child.length
      childTextReplacementChangeInLength += child.textReplacementChangeInLength
      node.hasTextReplacement = node.hasTextReplacement || child.hasTextReplacement
      assert(childLength + childTextReplacementChangeInLength == resultingAttributesArray.count - initialAttributesArrayCount)
    }
    node.textReplacementChangeInLength = childTextReplacementChangeInLength
    assert(node.length + node.textReplacementChangeInLength == resultingAttributesArray.count - initialAttributesArrayCount)
  }

  func applyReplacements(in node: SyntaxTreeNode, startingIndex: Int, to string: NSMutableString) {
    guard node.hasTextReplacement else { return }
    if let replacement = node.textReplacement {
      string.replaceCharacters(in: NSRange(location: startingIndex, length: node.length), with: String(utf16CodeUnits: replacement, count: replacement.count))
    } else {
      for (child, index) in node.childrenAndOffsets(startingAt: startingIndex).reversed() {
        applyReplacements(in: child, startingIndex: index, to: string)
      }
    }
  }
}

/// Key for storing the string attributes associated with a node.
private struct NodeAttributesKey: SyntaxTreeNodePropertyKey {
  typealias Value = AttributedStringAttributesDescriptor

  static let key = "attributes"
}

private struct NodeTextReplacementKey: SyntaxTreeNodePropertyKey {
  typealias Value = [unichar]
  static let key = "textReplacement"
}

private struct NodeHasTextReplacementKey: SyntaxTreeNodePropertyKey {
  typealias Value = Bool
  static let key = "hasTextReplacement"
}

private struct NodeTextReplacementChangeInLengthKey: SyntaxTreeNodePropertyKey {
  typealias Value = Int
  static let key = "textReplacementChangeInLength"
}

private extension SyntaxTreeNode {
  /// The attributes associated with this node, if set.
  var attributedStringAttributes: AttributedStringAttributesDescriptor? {
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

  func childrenAndOffsets(startingAt offset: Int) -> [(child: SyntaxTreeNode, offset: Int)] {
    var offset = offset
    var results = [(child: SyntaxTreeNode, offset: Int)]()
    for child in children {
      results.append((child: child, offset: offset))
      offset += child.length
    }
    return results
  }
}
