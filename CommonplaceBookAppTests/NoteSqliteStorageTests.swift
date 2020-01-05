// Copyright © 2017-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
import MiniMarkdown
import XCTest

final class NoteSqliteStorageTests: XCTestCase {
  func testCanOpenNonexistantFile() {
    let database = makeAndOpenEmptyDatabase()
    try? FileManager.default.removeItem(at: database.fileURL)
  }

  func testCannotOpenTwice() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    let openExpectation = expectation(description: "Did open")
    database.open { error in
      XCTAssertNotNil(error)
      openExpectation.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  func testCanSaveEmptyDatabase() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    let saveExpectation = expectation(description: "did save")
    database.saveIfNeeded { error in
      XCTAssertNil(error)
      saveExpectation.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  func testRoundTripSimpleNoteContents() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.simpleTest)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.simpleTest, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpdateSimpleNote() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      var note = Note.simpleTest
      let identifier = try database.createNote(note)
      note.text = "Version 2.0 text"
      try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in note })
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(note, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRoundTripHashtagNoteContents() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withHashtags, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpdateHashtags() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      try database.updateNote(noteIdentifier: identifier, updateBlock: { oldNote -> Note in
        var note = oldNote
        note.metadata.hashtags = ["#updated"]
        return note
      })
      let roundTripNote = try database.note(noteIdentifier: identifier)
      var expectedNote = Note.withHashtags
      expectedNote.metadata.hashtags = ["#updated"]
      XCTAssertEqual(expectedNote, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpdateNoteWithChallenges() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withChallenges)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withChallenges, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRemoveChallengesFromNote() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withChallenges)
      try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in Note.simpleTest })
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.simpleTest, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testNotesShowUpInAllMetadata() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      XCTAssertEqual(1, database.allMetadata.count)
      XCTAssertEqual(database.allMetadata[identifier], Note.withHashtags.metadata)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testCreatingNoteSendsNotification() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      var didGetNotification = false
      let cancellable = database.notesDidChange.sink { didGetNotification = true }
      _ = try database.createNote(Note.simpleTest)
      XCTAssertTrue(didGetNotification)
      cancellable.cancel()
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testDeleteNote() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withHashtags, roundTripNote)
      try database.deleteNote(noteIdentifier: identifier)
      XCTAssertThrowsError(try database.note(noteIdentifier: identifier))
      XCTAssertEqual(0, try database.countOfTextRows())
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testStoreData() {
    let database = makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let data = "Hello, world!".data(using: .utf8)!
      let identifier = try database.storeAssetData(data, typeHint: "public/text")
      let roundTrip = try database.data(for: identifier)
      XCTAssertEqual(data, roundTrip)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private extension NoteSqliteStorageTests {
  @discardableResult
  func makeAndOpenEmptyDatabase() -> NoteSqliteStorage {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteSqliteStorage(fileURL: fileURL, parsingRules: ParsingRules())
    let openExpectation = expectation(description: "Did open")
    database.open { error in
      XCTAssertNil(error)
      openExpectation.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    return database
  }
}

private extension Note {
  static let simpleTest = Note(
    metadata: Note.Metadata(
      timestamp: Date(),
      hashtags: [],
      title: "Testing",
      containsText: true
    ),
    text: "This is a test",
    challengeTemplates: []
  )

  static let withHashtags = Note(
    metadata: Note.Metadata(
      timestamp: Date(),
      hashtags: ["#ashtag"],
      title: "Testing",
      containsText: true
    ),
    text: "This is a test",
    challengeTemplates: []
  )

  static let withChallenges = Note(markdown: """
  # Shakespeare quotes

  > To be, or not to be, that is the question. (Hamlet)

  """, parsingRules: ParsingRules())
}
