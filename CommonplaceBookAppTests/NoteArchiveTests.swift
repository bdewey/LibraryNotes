// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBookApp
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
      try archive.insertNote(Examples.vocabulary.rawValue, contentChangeTime: now.addingTimeInterval(3600))
      try archive.insertNote(Examples.quotes.rawValue, contentChangeTime: now.addingTimeInterval(3600))
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
      XCTAssertEqual(archive.versions.count, 1)
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
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, contentChangeTime: now.addingTimeInterval(3600))
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
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
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, contentChangeTime: now.addingTimeInterval(3600))
      let modifiedText = Examples.vocabulary.rawValue + "* Tu ?[to be](eres) americano.\n"
      archive.updateText(
        for: noteIdentifier,
        to: modifiedText,
        contentChangeTime: now.addingTimeInterval(3600)
      )
      XCTAssertEqual(archive.pageProperties.count, 0)
      archive.batchUpdatePageProperties()
      XCTAssertEqual(archive.pageProperties.count, 1)
      XCTAssertEqual(archive.versions.count, 0)
      XCTAssertEqual(modifiedText, try archive.currentText(for: noteIdentifier))
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3601))
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
      let noteIdentifier = try archive.insertNote(Examples.vocabulary.rawValue, contentChangeTime: now.addingTimeInterval(3600))
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
      let preModifiedArchive = archive
      archive.updateText(
        for: noteIdentifier,
        to: Examples.vocabulary.rawValue,
        contentChangeTime: now.addingTimeInterval(3600)
      )
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(7200))
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
      try archive.archivePageManifestVersion(timestamp: now)
      XCTAssertEqual(archive.versions.count, 1)

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
      try archive.archivePageManifestVersion(timestamp: now)
      XCTAssertEqual(regeneratedArchive.versions.count, 1)

      // Change quotes. Now we get a new version but not a new page.
      try regeneratedArchive.importFile(
        named: "quotes.txt",
        text: Examples.quotes.rawValue + "\n> This is a new quote!\n",
        contentChangeDate: contentChangeDate.addingTimeInterval(30),
        importDate: now
      )
      try regeneratedArchive.archivePageManifestVersion(timestamp: now)
      XCTAssertEqual(regeneratedArchive.versions.count, 2)
      XCTAssertEqual(regeneratedArchive.pageProperties.count, 2)
      print(regeneratedArchive.textSerialized())
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRemovePage() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      // Create some filler files, just to make sure we start using delta encodings for pages &
      // versions.
      for delay in 0 ..< 10 {
        try archive.insertNote(
          "All work and no play makes Jack a dull boy",
          contentChangeTime: now.addingTimeInterval(TimeInterval(delay))
        )
      }
      let survivor = try archive.insertNote(
        Examples.vocabulary.rawValue,
        contentChangeTime: now
      )
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(100))
      let victim = try archive.insertNote(
        Examples.quotes.rawValue,
        contentChangeTime: now.addingTimeInterval(3600)
      )
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
      // By removing the last note, the page manifest will now be exactly the same as one version
      // ago. This test case deliberately provokes that to make sure we don't create a cycle
      // of delta-encoding.
      archive.removeNote(for: victim)
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3601))
      XCTAssertEqual(archive.versions.count, 3)
      XCTAssertEqual(archive.pageProperties.count, 11)
      let serialized = archive.textSerialized()
      print(serialized)
      let roundTrip = try NoteArchive(parsingRules: parsingRules, textSerialization: serialized)
      // Have to compare formatted timestamps because we lose precision in serialization
      let dateFormatter = ISO8601DateFormatter()
      XCTAssertEqual(
        roundTrip.versions.map(dateFormatter.string),
        archive.versions.map(dateFormatter.string)
      )
      XCTAssertEqual(Examples.vocabulary.rawValue, try roundTrip.currentText(for: survivor))
      XCTAssertThrowsError(try roundTrip.currentText(for: victim))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  /// the goal is to create the exact same text at multiple points in the version history of a page
  /// to make sure we don't create a diff cycle
  func testPageVersionCycle() {
    var archive = NoteArchive(parsingRules: parsingRules)
    let now = Date()
    do {
      let noteIdentifier = try archive.insertNote(
        Examples.vocabulary.rawValue,
        contentChangeTime: now
      )
      try archive.archivePageManifestVersion(timestamp: now)
      archive.updateText(
        for: noteIdentifier,
        to: Examples.vocabulary.rawValue + "blah\n",
        contentChangeTime: now.addingTimeInterval(3600)
      )
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
      archive.updateText(
        for: noteIdentifier,
        to: Examples.vocabulary.rawValue,
        contentChangeTime: now.addingTimeInterval(7200)
      )
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(7200))
      XCTAssertEqual(archive.versions.count, 3)
      XCTAssertEqual(Examples.vocabulary.rawValue, try archive.currentText(for: noteIdentifier))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testInsertAndUpdateRawProperties() {
    var archive = NoteArchive(parsingRules: parsingRules)
    do {
      let now = Date()
      var properties = PageProperties()
      properties.title = "Vocabulary List with a Really Long Title"
      properties.hashtags = ["#testing"]
      properties.timestamp = now
      let key = archive.insertPageProperties(properties)
      let roundTrip = archive.pageProperties[key]
      XCTAssertEqual(roundTrip, properties)
      try archive.archivePageManifestVersion(timestamp: now)
      properties.cardTemplates = [
        "12345:vocab",
        "7890:vocab",
      ]
      archive.updatePageProperties(for: key, to: properties)
      try archive.archivePageManifestVersion(timestamp: now.addingTimeInterval(3600))
      let serialized = archive.textSerialized()
      print(serialized)
      let newArchive = try NoteArchive(parsingRules: parsingRules, textSerialization: serialized)
      XCTAssertEqual(newArchive.pageProperties[key], properties)
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
