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
}

extension ParsedString: RangeReplaceableSafeUnicodeBuffer {
  public typealias Index = PieceTable.Index

  public var count: Int { text.count }

  public subscript(range: NSRange) -> [unichar] { text[range] }

  public func utf16(at index: Int) -> unichar? {
    return text.utf16(at: index)
  }

  public override func replaceCharacters(in range: NSRange, with str: String) {
    text.replaceCharacters(in: range, with: str)
    memoizationTable.applyEdit(originalRange: range, replacementLength: str.utf16.count)
    result = Result {
      try memoizationTable.parseBuffer(text)
    }
  }

  public var string: String { text.string }
}
