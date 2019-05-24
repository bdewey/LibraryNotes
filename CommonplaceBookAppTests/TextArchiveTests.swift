// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class TextArchiveTests: XCTestCase {

  func testSimpleChunks() {
    let chunk = TextSnippet("no newline")
    XCTAssertEqual(chunk.text, "no newline\n")
    XCTAssertEqual(chunk.sha1Digest, "5baa7f79aea31cf9d11147282faac9f95dff4a27")
    XCTAssertEqual(chunk.text.sha1Digest(), chunk.sha1Digest)
  }

  func testSerializeOneChunk() {
    let chunk = TextSnippet("This is two lines\nof text.\n")
    let serializedForm = chunk.textSerialized()
    print(serializedForm)
    do {
      let roundTrip = try TextSnippet(textSerialization: serializedForm)
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
    var archive = TextSnippetArchive()
    let chunks = texts.map { archive.append($0) }
    XCTAssertEqual(chunks[0].sha1Digest, "5baa7f79aea31cf9d11147282faac9f95dff4a27")
    XCTAssertEqual(chunks[1].sha1Digest, texts[1].sha1Digest())
    do {
      let serializedForm = archive.textSerialized()
      print(serializedForm)
      let roundTrip = try TextSnippetArchive(textSerialization: serializedForm)
      XCTAssertEqual(roundTrip, archive)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testCanSerializeAsDiff() {
    var archive = TextSnippetArchive()
    let parent = archive.append(testContent)
    let modifiedContent = testContent + "\n> This is a fake new quote\n"
    let child = archive.append(modifiedContent, parent: parent)
    XCTAssertEqual(child.text, modifiedContent)
    let serialized = archive.textSerialized()
    do {
      let roundTrip = try TextSnippetArchive(textSerialization: serialized)
      XCTAssertEqual(roundTrip, archive)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  /// We only use delta encoding if it actually saves space.
  func testDeltaOptimization() {
    let parent = TextSnippet("dog")
    let child = TextSnippet(text: "cat", parent: parent)
    let expectedSerialization = """
+++ 8f6abfbac8c81b55f9005f7ec09e32d29e40eb40 1
cat

"""
    XCTAssertEqual(child.textSerialized(), expectedSerialization)
  }
}

private let testContent = """
# *Educated*, Tara Westover

* The author of *Educated* is ?[](Tara Westover).
* *Educated* takes place at ?[mountain name](Buck’s Peak), in ?[state](Idaho).
* Tara Westover did her undergraduate education at ?[collage](BYU).

## Quotes

> It’s a tranquillity born of sheer immensity; it calms with its very magnitude, which renders the merely human of no consequence. (26)

> Ain’t nothin’ funnier than real life, I tell you what. (34)

> Choices, numberless as grains of sand, had layered and compressed, coalescing into sediment, then into rock, until all was set in stone. (35)

> My brothers were like a pack of wolves. They tested each other constantly, with scuffles breaking out every time some young pup hit a growth spurt and dreamed of moving up. (43)

> In retrospect, I see that this was my education, the one that would matter: the hours I spent sitting at a borrowed desk, struggling to parse narrow strands of Mormon doctrine in mimicry of a brother who’d deserted me. The skill I was learning was a crucial one, the patience to read things I could not yet understand. (62)

"""
