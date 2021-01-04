// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import UIKit

/// A function that modifies NSAttributedString attributes based the syntax tree.
public typealias FormattingFunction = (SyntaxTreeNode, inout AttributedStringAttributes) -> Void

/// A function that overlays replacements...
public typealias ReplacementFunction = (SyntaxTreeNode, Int, SafeUnicodeBuffer) -> [unichar]?

private extension Logger {
  static let attributedStringLogger = Logger(label: "org.brians-brain.ParsedAttributedString")
}

@objc public protocol ParsedAttributedStringDelegate: AnyObject {
  /// Notifies a delegate that the contents of the string changed.
  ///
  /// - Parameters:
  ///   - oldRange: The extent of characters affected before the change took place.
  ///   - changeInLength: Change in length of the total string because of this edit.
  ///   - changedAttributesRange: Range of characters in `string` that have updated attributes. If `changedAttributesRange.location` is NSNotFound, then the attributes did not change.
  func attributedStringDidChange(oldRange: NSRange, changeInLength: Int, changedAttributesRange: NSRange)
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
@objc public final class ParsedAttributedString: NSMutableAttributedString {
  public struct Settings {
    var grammar: PackratGrammar
    var defaultAttributes: AttributedStringAttributes
    var formattingFunctions: [SyntaxTreeNodeType: FormattingFunction]
    var replacementFunctions: [SyntaxTreeNodeType: ReplacementFunction]
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

  override public convenience init() {
    assertionFailure("Are you sure you want a plain-text attributed string?")
    self.init(
      grammar: PlainTextGrammar(),
      defaultAttributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label],
      formattingFunctions: [:],
      replacementFunctions: [:]
    )
  }

  public init(
    string: String = "",
    grammar: PackratGrammar,
    defaultAttributes: AttributedStringAttributes,
    formattingFunctions: [SyntaxTreeNodeType: FormattingFunction],
    replacementFunctions: [SyntaxTreeNodeType: ReplacementFunction]
  ) {
    self.defaultAttributes = defaultAttributes
    self.formattingFunctions = formattingFunctions
    self.replacementFunctions = replacementFunctions
    self.rawString = ParsedString(string, grammar: grammar)
    self._string = PieceTableString(pieceTable: PieceTable(rawString.text))
    super.init()
    var range: Range<Int>?
    if case .success(let node) = rawString.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        leafNodeRange: &range
      )
      applyReplacements(in: node, startingIndex: 0, to: _string)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc public weak var delegate: ParsedAttributedStringDelegate?

  // MARK: - Stored properties

  /// The "raw" contents of the string. This is what is parsed, and determines what replacements get applied to determine the final contents.
  public let rawString: ParsedString

  /// The underlying NSString that backs `string`. This is public and exposed to Objective-C to allow O(1) access to the string contents from TextKit.
  @objc public let _string: PieceTableString // swiftlint:disable:this identifier_name

  /// The contents of the string. This is derived from `rawString` after applying replacements.
  override public var string: String { _string as String }

  /// Default attributes
  private let defaultAttributes: AttributedStringAttributes

  /// A set of functions that customize attributes based upon the nodes in the AST.
  private let formattingFunctions: [SyntaxTreeNodeType: FormattingFunction]

  /// A set of functions that replace the contents of `rawString` -- e.g., these can be used to remove delimiters or change spaces to tabs.
  private let replacementFunctions: [SyntaxTreeNodeType: ReplacementFunction]

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
  public func path(to index: Int) -> [AnchoredNode] { rawString.path(to: index) }

  /// Replaces the characters in the given range with the characters of the given string.
  override public func replaceCharacters(in range: NSRange, with str: String) {
    var changedAttributesRange: Range<Int>?
    let lengthBeforeChanges = _string.length
    let bufferRange = rawStringRange(forRange: range)
    rawString.replaceCharacters(
      in: bufferRange,
      with: str
    )
    _string.revertToOriginal()
    if case .success(let node) = rawString.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        leafNodeRange: &changedAttributesRange
      )
      applyReplacements(in: node, startingIndex: 0, to: _string)
    }
    // Deliver delegate messages
    Logger.attributedStringLogger.debug("Edit \(range) change in length \(_string.length - lengthBeforeChanges)")
    if let range = changedAttributesRange {
      Logger.attributedStringLogger.debug("Changed attributes at \(self.range(forRawStringRange: NSRange(range)))")
    }
    delegate?.attributedStringDidChange(
      oldRange: range,
      changeInLength: _string.length - lengthBeforeChanges,
      changedAttributesRange: changedAttributesRange.flatMap { self.range(forRawStringRange: NSRange($0)) }
        ?? NSRange(location: 0, length: 0) // Documentation says location == NSNotFound means "no change", but this seems to cause an infinite loop
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
    guard let tree = try? rawString.result.get() else {
      range?.pointee = NSRange(location: 0, length: rawString.count)
      return defaultAttributes
    }
    var bufferLocation = rawStringRange(forRange: NSRange(location: location, length: 0)).location
    repeat {
      // Crash on invalid location or if I didn't set attributes (shouldn't happen?)
      let leafNode = try! tree.leafNode(containing: bufferLocation) // swiftlint:disable:this force_try
      let visibleRange = self.range(forRawStringRange: leafNode.range)
      if visibleRange.length > 0 {
        assert(visibleRange.contains(location))
        range?.pointee = visibleRange
        Logger.attributedStringLogger.debug("Found attributes at location \(bufferLocation) for range \(visibleRange) (\(visibleRange.upperBound)), length = \(length)")
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
  override public func setAttributes(
    _ attrs: [NSAttributedString.Key: Any]?,
    range: NSRange
  ) {
    // TODO. Maybe just ignore? But this is how emojis and misspellings get formatted
    // by the system.
  }
}

// MARK: - Private

private extension ParsedAttributedString {
  /// Associates AttributedStringAttributes with this part of the syntax tree.
  func applyAttributes(
    to node: SyntaxTreeNode,
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
    if let replacementFunction = replacementFunctions[node.type], let textReplacement = replacementFunction(node, startingIndex, rawString) {
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

// MARK: - Stylesheets

// TODO: Move this to a separate file?

public extension ParsedAttributedString.Settings {
  static func plainText(
    textStyle: UIFont.TextStyle,
    textColor: UIColor = .label,
    extraAttributes: [NSAttributedString.Key: Any] = [:]
  ) -> ParsedAttributedString.Settings {
    var formattingFunctions = [SyntaxTreeNodeType: FormattingFunction]()
    var replacementFunctions = [SyntaxTreeNodeType: ReplacementFunction]()
    formattingFunctions[.emphasis] = { $1.italic = true }
    formattingFunctions[.strongEmphasis] = { $1.bold = true }
    formattingFunctions[.code] = { $1.familyName = "Menlo" }
    replacementFunctions[.delimiter] = { _, _, _ in [] }
    replacementFunctions[.clozeHint] = { _, _, _ in [] }
    var defaultAttributes: AttributedStringAttributes = [
      .font: UIFont.preferredFont(forTextStyle: textStyle),
      .foregroundColor: textColor,
    ]
    defaultAttributes.lineHeightMultiple = 1.2
    defaultAttributes.merge(extraAttributes, uniquingKeysWith: { _, new in new })
    return ParsedAttributedString.Settings(
      grammar: MiniMarkdownGrammar.shared,
      defaultAttributes: defaultAttributes,
      formattingFunctions: formattingFunctions,
      replacementFunctions: replacementFunctions
    )
  }
}

/// Key for storing the string attributes associated with a node.
private struct NodeAttributesKey: SyntaxTreeNodePropertyKey {
  typealias Value = AttributedStringAttributes

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
