// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import FlashcardKit
import MiniMarkdown
import XCTest

private let parsingRules: MiniMarkdown.ParsingRules = {
  var parsingRules = MiniMarkdown.ParsingRules()
  parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
  return parsingRules
}()

final class NoteArchiveTests: XCTestCase {
  func testInsertPages() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      try archive.insertNote(Examples.vocabulary.rawValue, timestamp: now)
      try archive.insertNote(Examples.quotes.rawValue, timestamp: now.addingTimeInterval(3600))
      XCTAssertEqual(archive.versions.count, 2)
      let serialized = archive.textSerialized()
      print(serialized)
      let roundTrip = try NoteArchive(parsingRules: parsingRules, textSerialization: serialized)
      // Have to compare formatted timestamps because we lose precision in serialization
      let dateFormatter = ISO8601DateFormatter()
      XCTAssertEqual(
        roundTrip.versions.map(dateFormatter.string),
        archive.versions.map(dateFormatter.string)
      )
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRetrievePageText() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, timestamp: now)
      let serialized = archive.textSerialized()
      print(serialized)
      let retrievedText = try archive.currentText(for: noteIdentifier)
      XCTAssertEqual(retrievedText, Examples.vocabulary.rawValue)

      let roundTrip = try NoteArchive(parsingRules: parsingRules, textSerialization: serialized)
      let roundTripRetrieved = try roundTrip.currentText(for: noteIdentifier)
      XCTAssertEqual(roundTripRetrieved, Examples.vocabulary.rawValue)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testModifyPageText() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, timestamp: now)
      let modifiedText = Examples.vocabulary.rawValue + "* Tu ?[to be](eres) americano.\n"
      try archive.updateText(
        for: noteIdentifier,
        to: modifiedText,
        at: now.addingTimeInterval(3600)
      )
      XCTAssertEqual(archive.pageProperties.count, 1)
      XCTAssertEqual(archive.versions.count, 2)
      XCTAssertEqual(modifiedText, try archive.currentText(for: noteIdentifier))
      let serialized = archive.textSerialized()
      print(serialized)
      let retrievedText = try archive.currentText(for: noteIdentifier)
      XCTAssertEqual(retrievedText, modifiedText)

      let roundTrip = try NoteArchive(parsingRules: parsingRules, textSerialization: serialized)
      let roundTripRetrieved = try roundTrip.currentText(for: noteIdentifier)
      XCTAssertEqual(roundTripRetrieved, modifiedText)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testModifyToIdenticalContentIsNoOp() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, timestamp: now)
      let preModifiedArchive = archive
      try archive.updateText(
        for: noteIdentifier,
        to: Examples.vocabulary.rawValue,
        at: now.addingTimeInterval(3600)
      )
      XCTAssertEqual(archive.versions.count, 1)
      XCTAssertEqual(
        archive.pageProperties,
        preModifiedArchive.pageProperties,
        "Archives do not match"
      )
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFileImports() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    let contentChangeDate = now.addingTimeInterval(-1 * 3600) // one hour ago
    do {
      try archive.importFile(
        named: "vocabulary.txt",
        text: Examples.vocabulary.rawValue,
        contentChangeDate: contentChangeDate,
        importDate: now
      )
      try archive.importFile(
        named: "quotes.txt",
        text: Examples.quotes.rawValue,
        contentChangeDate: contentChangeDate,
        importDate: now
      )
      XCTAssertEqual(archive.versions.count, 2)

      // Make sure the file import table is serialized / deserialized.
      var regeneratedArchive = try NoteArchive(
        parsingRules: parsingRules,
        textSerialization: archive.textSerialized()
      )

      // Try to reimport, nothing should change.
      try regeneratedArchive.importFile(
        named: "vocabulary.txt",
        text: Examples.vocabulary.rawValue,
        contentChangeDate: contentChangeDate,
        importDate: now
      )
      try regeneratedArchive.importFile(
        named: "quotes.txt",
        text: Examples.quotes.rawValue,
        contentChangeDate: contentChangeDate,
        importDate: now
      )
      XCTAssertEqual(regeneratedArchive.versions.count, 2)

      // Change quotes. Now we get a new version but not a new page.
      try regeneratedArchive.importFile(
        named: "quotes.txt",
        text: Examples.quotes.rawValue + "\n> This is a new quote!\n",
        contentChangeDate: contentChangeDate.addingTimeInterval(30),
        importDate: now
      )
      XCTAssertEqual(regeneratedArchive.versions.count, 3)
      XCTAssertEqual(regeneratedArchive.pageProperties.count, 2)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private enum Examples: String {
  case vocabulary = """
  # Spanish study

  | Spanish           | Engish |
  | ----------------- | ------ |
  | tenedor #spelling | fork   |
  | hombre            | man    |

  1. *Ser* is used to identify a person, an animal, a concept, a thing, or any noun.
  2. *Estar* is used to show location.
  3. *Ser*, with an adjective, describes the "norm" of a thing.
  - La nieve ?[to be](es) blanca.
  4. *Estar* with an adjective shows a "change" or "condition."

  * Yo ?[to be](soy) de España. ¿De dónde ?[to be](es) ustedes?

"""

  case quotes = """
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
}
