// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import Logging

private let logger = Logger(label: "PieceTableString")

/// An NSMutableString subclass that uses a PieceTable for its underlying storage.
@objc public class PieceTableString: NSMutableString {
  /// The underlying storage. Public so mutations can happen directly to its contents.
  private(set) public var pieceTable: PieceTable

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

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override var length: Int {
    return pieceTable.count
  }

  public override func character(at index: Int) -> unichar {
    pieceTable[pieceTable.index(pieceTable.startIndex, offsetBy: index)]
  }

  public override func getCharacters(_ buffer: UnsafeMutablePointer<unichar>, range: NSRange) {
    let nativeRange = Range(range, in: pieceTable)!
    pieceTable.copyCharacters(at: nativeRange, to: buffer)
  }

  public override func replaceCharacters(in range: NSRange, with aString: String) {
    pieceTable.replaceSubrange(Range(range, in: pieceTable)!, with: aString.utf16)
  }

  public func revertToOriginal() { pieceTable.revertToOriginal() }
}

extension PieceTableString: SafeUnicodeBuffer {
  public var count: Int { self.length }

  public func utf16(at index: Int) -> unichar? {
    if index >= length { return nil }
    return character(at: index)
  }

  public subscript(range: NSRange) -> [unichar] { pieceTable[range] }

  public var string: String { pieceTable.string }
}
