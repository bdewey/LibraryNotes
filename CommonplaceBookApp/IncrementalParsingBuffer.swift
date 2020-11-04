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

public final class IncrementalParsingBuffer {
  public init(_ string: String, grammar: PackratGrammar) {
    let pieceTable = PieceTable(string)
    self.grammar = grammar
    let memoizationTable = MemoizationTable(grammar: grammar)
    let result = Result {
      try memoizationTable.parseBuffer(pieceTable)
    }
    self.pieceTable = pieceTable
    self.memoizationTable = memoizationTable
    self.result = result
  }

  private var pieceTable: PieceTable
  private let memoizationTable: MemoizationTable
  private let grammar: PackratGrammar
  public private(set) var result: Result<NewNode, Error>
}

extension IncrementalParsingBuffer: RangeReplaceableSafeUnicodeBuffer {
  public typealias Index = PieceTable.Index

  public var count: Int { pieceTable.count }

  public subscript(range: NSRange) -> [unichar] { pieceTable[range] }

  public subscript<R>(range: R) -> [unichar] where R: RangeExpression, R.Bound == Index {
    return pieceTable[range]
  }

  public func utf16(at index: Int) -> unichar? {
    return pieceTable.utf16(at: index)
  }

  public func replaceCharacters(in range: NSRange, with str: String) {
    pieceTable.replaceCharacters(in: range, with: str)
    memoizationTable.applyEdit(originalRange: range, replacementLength: str.utf16.count)
    result = Result {
      try memoizationTable.parseBuffer(pieceTable)
    }
  }

  public var string: String { pieceTable.string }
}
