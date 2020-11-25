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
import Logging

private let logger = Logger(label: "PieceTableString")

/// An NSMutableString subclass that uses a PieceTable for its underlying storage.
@objc public class PieceTableString: NSMutableString {
  /// The underlying storage. Public so mutations can happen directly to its contents.
  public private(set) var pieceTable: PieceTable

  override public init() {
    self.pieceTable = PieceTable()
    super.init()
  }

  override public init(capacity: Int) {
    self.pieceTable = PieceTable()
    super.init()
  }

  init(pieceTable: PieceTable) {
    self.pieceTable = pieceTable
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public var length: Int {
    return pieceTable.count
  }

  override public func character(at index: Int) -> unichar {
    pieceTable[pieceTable.index(pieceTable.startIndex, offsetBy: index)]
  }

  override public func getCharacters(_ buffer: UnsafeMutablePointer<unichar>, range: NSRange) {
    let nativeRange = Range(range, in: pieceTable)!
    pieceTable.copyCharacters(at: nativeRange, to: buffer)
  }

  override public func replaceCharacters(in range: NSRange, with aString: String) {
    pieceTable.replaceSubrange(Range(range, in: pieceTable)!, with: aString.utf16)
  }

  public func revertToOriginal() { pieceTable.revertToOriginal() }
}

extension PieceTableString: SafeUnicodeBuffer {
  public var count: Int { length }

  public func utf16(at index: Int) -> unichar? {
    if index >= length { return nil }
    return character(at: index)
  }

  public subscript(range: NSRange) -> [unichar] { pieceTable[range] }

  public var string: String { pieceTable.string }
}
