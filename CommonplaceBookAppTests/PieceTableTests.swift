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

@testable import CommonplaceBookApp
import Foundation
import XCTest

final class PieceTableTests: XCTestCase {
  func testOriginalLength() {
    let pieceTable = PieceTable("Hello, world")
    XCTAssertEqual(12, pieceTable.count)
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testAppendSingleCharacter() {
    var pieceTable = PieceTable("Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 12, length: 0), with: "!")
    XCTAssertEqual("Hello, world!", pieceTable.string)
  }

  func testInsertCharacterInMiddle() {
    var pieceTable = PieceTable("Hello world")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 0), with: ",")
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testDeleteCharacterInMiddle() {
    var pieceTable = PieceTable("Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 1), with: "")
    XCTAssertEqual("Hello world", pieceTable.string)
  }

  func testDeleteFromBeginning() {
    var pieceTable = PieceTable("_Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 1), with: "")
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testDeleteAtEnd() {
    var pieceTable = PieceTable()
    pieceTable.append(contentsOf: "Hello, world!?".utf16)
    let lastCharacterIndex = pieceTable.index(pieceTable.startIndex, offsetBy: pieceTable.count - 1)
    pieceTable.remove(at: lastCharacterIndex)
    XCTAssertEqual("Hello, world!", pieceTable.string)
  }

  func testInsertAtBeginning() {
    var pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 0), with: "¡")
    XCTAssertEqual("¡Hello, world!", pieceTable.string)
  }

  func testLeftOverlappingEditRange() {
    var pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 7, length: 0), with: "zCRuel ")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 10), with: "Goodbye, cr")
    XCTAssertEqual("Goodbye, cruel world!", pieceTable.string)
  }

  func testRightOverlappingEditRange() {
    var pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 4, length: 2), with: "a,")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 2), with: "!! ")
    XCTAssertEqual("Hella!! world!", pieceTable.string)
    XCTAssertEqual(pieceTable.utf16String, pieceTable.string)
  }

  func testDeleteAddedOverlappingRange() {
    var pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 7, length: 0), with: "nutty ")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 13), with: "")
    XCTAssertEqual("Hello!", pieceTable.string)
  }

  func testAppend() {
    var pieceTable = PieceTable("")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Hello, world!")
    XCTAssertEqual(pieceTable.string, "Hello, world!")
  }

  func testRepeatedAppend() {
    var pieceTable = PieceTable()
    let expected = "Hello, world!!"
    for character in expected.utf16 {
      pieceTable.append(character)
    }
    XCTAssertEqual(pieceTable.string, expected)
  }

  func testAppendPerformance() {
    measure {
      var pieceTable = PieceTable("")
      for i in 0 ..< 1024 {
        pieceTable.replaceCharacters(in: NSRange(location: i, length: 0), with: ".")
      }
    }
  }

  /// This does two large "local" edits. First it puts 512 characters sequentially into the buffer.
  /// Then it puts another 512 characters sequentially into the middle.
  /// Logically this can be represented in 3 runs so manipulations should stay fast.
  func testLargeLocalEditPerformance() {
    let expected = String(repeating: "A", count: 256) + String(repeating: "B", count: 512) + String(repeating: "A", count: 256)
    measure {
      var pieceTable = PieceTable("")
      for i in 0 ..< 512 {
        pieceTable.replaceCharacters(in: NSRange(location: i, length: 0), with: "A")
      }
      for i in 0 ..< 512 {
        pieceTable.replaceCharacters(in: NSRange(location: 256 + i, length: 0), with: "B")
      }
      XCTAssertEqual(pieceTable.string, expected)
    }
  }

  let megabyteText = String(repeating: " ", count: 1024 * 1024)

  func testMegabytePieceTablePerformance() {
    measure {
      var pieceTable = PieceTable(megabyteText)
      for i in 0 ..< 50 * 1024 {
        pieceTable.replaceCharacters(in: NSRange(location: 1024 + i, length: 0), with: ".")
      }
    }
  }

  func testMegabyteStringPerformance() {
    measure {
      var str = megabyteText
      var index = str.index(str.startIndex, offsetBy: 50 * 1024)
      for _ in 0 ..< 50 * 1024 {
        str.insert(".", at: index)
        index = str.index(after: index)
      }
    }
  }

  func testIndexMapping() {
    var pieceTable = PieceTable("# My *header* text")
    pieceTable.replaceSubrange(pieceTable.startIndex ..< pieceTable.index(pieceTable.startIndex, offsetBy: 2), with: Array("H1\t".utf16))
    XCTAssertEqual(pieceTable.string, "H1\tMy *header* text")
    pieceTable.replaceSubrange(pieceTable.index(at: 13) ..< pieceTable.index(at: 14), with: [])
    pieceTable.replaceSubrange(pieceTable.index(at: 6) ..< pieceTable.index(at: 7), with: [])
    print(pieceTable)
    XCTAssertEqual(pieceTable.string, "H1\tMy header text")
    XCTAssertEqual(pieceTable.indexForOriginalOffset(0), .notFound(lowerBound: nil, upperBound: PieceTable.Index(pieceIndex: 1, contentIndex: 2)))
    XCTAssertEqual(pieceTable.indexForOriginalOffset(3), .found(at: PieceTable.Index(pieceIndex: 1, contentIndex: 3)))
    XCTAssertEqual(pieceTable.originalOffsetForIndex(PieceTable.Index(pieceIndex: 1, contentIndex: 3)), .found(at: 3))
    XCTAssertEqual(pieceTable.originalOffsetForIndex(PieceTable.Index(pieceIndex: 0, contentIndex: 2)), .notFound(lowerBound: nil, upperBound: 2))
  }

  /// This never finishes in a reasonable amount of time :-(
  func DISABLE_testMegabyteTextStoragePerformance() {
    measure {
      let textStorage = NSTextStorage(attributedString: NSAttributedString(string: megabyteText))
      for i in 0 ..< 50 * 1024 {
        textStorage.replaceCharacters(in: NSRange(location: 1024 + i, length: 0), with: ".")
      }
    }
  }
}

// MARK: - Private

extension SafeUnicodeBuffer {
  var utf16String: String {
    var chars = [unichar]()
    var i = 0
    while let character = utf16(at: i) {
      chars.append(character)
      i += 1
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }
}
