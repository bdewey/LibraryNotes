// Copyright © 2017-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
import MiniMarkdown
import XCTest

// swiftlint:disable force_try

final class NoteSqliteStorageTests: XCTestCase {
  func testCanOpenNonexistantFile() {
    let database = try! makeAndOpenEmptyDatabase()
    try? FileManager.default.removeItem(at: database.fileURL)
  }

  func testCannotOpenTwice() {
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    XCTAssertThrowsError(try database.open())
  }

  func testCanSaveEmptyDatabase() {
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    XCTAssertNoThrow(try database.flush())
  }

  func testRoundTripSimpleNoteContents() {
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      try database.flush()
      XCTAssertFalse(database.hasUnsavedChanges)
      let identifier = try database.createNote(Note.simpleTest)
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.simpleTest, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpdateSimpleNote() {
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      try database.flush()
      XCTAssertFalse(database.hasUnsavedChanges)
      try database.updateNote(noteIdentifier: identifier, updateBlock: { oldNote -> Note in
        var note = oldNote
        note.metadata.hashtags = ["#updated"]
        return note
      })
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      var expectedNote = Note.withHashtags
      expectedNote.metadata.hashtags = ["#updated"]
      XCTAssertEqual(expectedNote, roundTripNote)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpdateNoteWithChallenges() {
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
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
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let identifier = try database.createNote(Note.withHashtags)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withHashtags, roundTripNote)
      try database.flush()
      XCTAssertFalse(database.hasUnsavedChanges)
      try database.deleteNote(noteIdentifier: identifier)
      XCTAssertTrue(database.hasUnsavedChanges)
      XCTAssertThrowsError(try database.note(noteIdentifier: identifier))
      XCTAssertEqual(0, try database.countOfTextRows())
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testStoreData() {
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      let data = "Hello, world!".data(using: .utf8)!
      try database.flush()
      XCTAssertFalse(database.hasUnsavedChanges)
      let identifier = try database.storeAssetData(data, typeHint: "public/text")
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTrip = try database.data(for: identifier)
      XCTAssertEqual(data, roundTrip)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testStudyLog() {
    let database = try! makeAndOpenEmptyDatabase()
    defer {
      try? FileManager.default.removeItem(at: database.fileURL)
    }
    do {
      _ = try database.createNote(Note.withChallenges)
      try database.flush()
      XCTAssertFalse(database.hasUnsavedChanges)
      var studySession = database.synchronousStudySession()
      XCTAssertEqual(1, studySession.count)
      while studySession.currentCard != nil {
        studySession.recordAnswer(correct: true)
      }
      try database.updateStudySessionResults(studySession, on: Date())
      XCTAssertTrue(database.hasUnsavedChanges)
      XCTAssertEqual(database.studyLog.count, studySession.count)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testSaveWhenExitScope() {
    do {
      let fileURL: URL
      let identifier: Note.Identifier
      do {
        let database = try makeAndOpenEmptyDatabase()
        fileURL = database.fileURL
        identifier = try database.createNote(Note.withHashtags)
      }
      do {
        let database = NoteSqliteStorage(fileURL: fileURL, parsingRules: ParsingRules())
        try database.open()
        let roundTripNote = try database.note(noteIdentifier: identifier)
        XCTAssertEqual(Note.withHashtags, roundTripNote)
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAutosaveHappens() {
    do {
      let database = try makeAndOpenEmptyDatabase()
      defer {
        try? FileManager.default.removeItem(at: database.fileURL)
      }
      let autosaveExpectation = expectation(description: "did autosave")
      let autosaveListener = database.didAutosave.sink {
        autosaveExpectation.fulfill()
      }
      _ = try database.createNote(Note.simpleTest)
      XCTAssertTrue(database.hasUnsavedChanges)
      waitForExpectations(timeout: 3, handler: nil)
      XCTAssertFalse(database.hasUnsavedChanges)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private extension NoteSqliteStorageTests {
  @discardableResult
  func makeAndOpenEmptyDatabase(autosaveTimeInterval: TimeInterval = 0.5) throws -> NoteSqliteStorage {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteSqliteStorage(fileURL: fileURL, parsingRules: ParsingRules(), autosaveTimeInterval: autosaveTimeInterval)
    try database.open()
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
