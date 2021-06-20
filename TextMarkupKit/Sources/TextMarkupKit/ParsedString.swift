// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// An NSMutableString subclass that parses its contents using the rules of `grammar` and makes
/// the abstract syntax tree available through `result`
@objc public final class ParsedString: NSMutableString {
  override public convenience init() {
    assertionFailure()
    self.init("", grammar: MiniMarkdownGrammar.shared)
  }

  override public convenience init(capacity: Int) {
    assertionFailure()
    self.init("", grammar: MiniMarkdownGrammar.shared)
  }

  public init(_ string: String, grammar: PackratGrammar) {
    let pieceTable = PieceTableString(pieceTable: PieceTable(string))
    self.grammar = grammar
    let memoizationTable = MemoizationTable(grammar: grammar)
    let result = Result {
      try memoizationTable.parseBuffer(pieceTable)
    }
    self.text = pieceTable
    self.memoizationTable = memoizationTable
    self.result = result
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let text: PieceTableString
  private let memoizationTable: MemoizationTable
  private let grammar: PackratGrammar
  public private(set) var result: Result<SyntaxTreeNode, Error>

  /// Returns the path through the syntax tree to the leaf node that contains `index`.
  /// - returns: An array of nodes where the first element is the root, and each subsequent node descends one level to the leaf.
  public func path(to index: Int) -> [AnchoredNode] {
    guard let root = try? result.get() else { return [] }
    return root.path(to: index)
  }

  #if DEBUG
  public enum ValidationError: Error {
    case unparsedText(String)
    case validationError(String)
  }

  @discardableResult
  public func parsedResultsThatMatch(
    _ expectedStructure: String
  ) throws -> SyntaxTreeNode {
    let tree = try result.get()
    if tree.length != count {
      let unparsedText = text[NSRange(location: tree.length, length: text.count - tree.length)]
      throw ValidationError.unparsedText(String(utf16CodeUnits: unparsedText, count: unparsedText.count))
    }
    if expectedStructure != tree.compactStructure {
      let errorMessage = """
Got:      \(tree.compactStructure)
Expected: \(expectedStructure)

\(tree.debugDescription(withContentsFrom: text))



\(TraceBuffer.shared)
"""
      throw ValidationError.validationError(errorMessage)
    }
    return tree
  }
  #endif
}

extension ParsedString: RangeReplaceableSafeUnicodeBuffer {
  public typealias Index = PieceTable.Index

  public var count: Int { text.count }

  public subscript(range: NSRange) -> [unichar] { text[range] }

  public func utf16(at index: Int) -> unichar? {
    return text.utf16(at: index)
  }

  public func character(at index: Int) -> Character? {
    return text.character(at: index)
  }

  override public func replaceCharacters(in range: NSRange, with str: String) {
    text.replaceCharacters(in: range, with: str)
    memoizationTable.applyEdit(originalRange: range, replacementLength: str.utf16.count)
    result = Result {
      try memoizationTable.parseBuffer(text)
    }
  }

  public var string: String { text.string }
}
