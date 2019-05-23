// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class TextArchiveTests: XCTestCase {

  func testSimpleChunks() {
    let chunk = TextArchive.Chunk("no newline")
    XCTAssertEqual(chunk.text, "no newline\n")
    XCTAssertEqual(chunk.sha1Digest, "5baa7f79aea31cf9d11147282faac9f95dff4a27")
    XCTAssertEqual(chunk.text.sha1Digest(), chunk.sha1Digest)
  }

  func testSerializeOneChunk() {
    let chunk = TextArchive.Chunk("This is two lines\nof text.\n")
    let serializedForm = chunk.textSerialized()
    print(serializedForm)
    do {
      let roundTrip = try TextArchive.Chunk(textSerialization: serializedForm)
      XCTAssertEqual(roundTrip, chunk)
    } catch {
      XCTFail("Unexpected parse error: \(error)")
    }
  }

  func testSeralizeMultipleChunks() {
    let texts = [
      "no newline",
      "This is two lines\nof text.\n",
      "abc\n123",
    ]
    var archive = TextArchive()
    let chunks = texts.map { archive.append($0) }
    XCTAssertEqual(chunks[0].sha1Digest, "5baa7f79aea31cf9d11147282faac9f95dff4a27")
    XCTAssertEqual(chunks[1].sha1Digest, texts[1].sha1Digest())
    do {
      let serializedForm = archive.textSerialized()
      print(serializedForm)
      let roundTrip = try TextArchive(textSerialization: serializedForm)
      XCTAssertEqual(roundTrip, archive)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testCanSerializeAsDiff() {
    var archive = TextArchive()
    let parent = archive.append("This is the original text.")
    let child = archive.append("This is the modified text.", parent: parent)
    let serialized = archive.textSerialized()
    print(serialized)
  }
}
