// Copyright © 2020 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class PieceTableTests: XCTestCase {
  func testGetCharacters() {
    let pieceTableString = PieceTableString()
    pieceTableString.append("Hello world")
    XCTAssertEqual("Hello world", pieceTableString as String)
    pieceTableString.replaceCharacters(in: NSRange(location: 5, length: 0), with: ",")
    XCTAssertEqual("Hello, world", pieceTableString as String)
    let rangeToExtract = NSRange(location: 5, length: pieceTableString.length - 6)
    var characters = Array<unichar>(repeating: 0, count: rangeToExtract.length)
    pieceTableString.getCharacters(&characters, range: rangeToExtract)
    let resultString = String(utf16CodeUnits: characters, count: characters.count)
    XCTAssertEqual(resultString, ", worl")
  }

  func testCopyContents() {
    let pieceTable = PieceTable("Hello, world.")
    let chars = pieceTable[pieceTable.startIndex...]
    XCTAssertEqual(chars.count, 13)
    let string = String(utf16CodeUnits: chars, count: chars.count)
    XCTAssertEqual(string, "Hello, world.")
  }
}
