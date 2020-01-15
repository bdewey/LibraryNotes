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
      let key = try database.storeAssetData(data, key: "test.txt")
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTrip = try database.data(for: key)
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
      // New items aren't eligible for at 3-5 days.
      let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
      var studySession = database.synchronousStudySession(date: future)
      XCTAssertEqual(1, studySession.count)
      while studySession.currentCard != nil {
        studySession.recordAnswer(correct: true)
      }
      try database.updateStudySessionResults(studySession, on: Date(), buryRelatedChallenges: true)
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

  func testConversion() {
    let bundle = Bundle(for: Self.self)
    guard let notebundleURL = bundle.url(forResource: "archive", withExtension: "notebundle") else {
      XCTFail("Could not file test content to migrate")
      return
    }
    let destinationURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("archive")
      .appendingPathExtension("notedb")
    try? FileManager.default.removeItem(at: destinationURL)
    let parsingRules = ParsingRules.commonplace
    let notebundle = NoteDocumentStorage(fileURL: notebundleURL, parsingRules: parsingRules)
    let openHappened = expectation(description: "open happened")
    notebundle.open { success in
      XCTAssert(success)
      let destination = NoteSqliteStorage(fileURL: destinationURL, parsingRules: parsingRules)
      do {
        try destination.open()
        try notebundle.migrate(to: destination)
        print("Copied archive to \(destination.fileURL.path)")
      } catch {
        XCTFail("Unexpected error copying contents: \(error)")
      }
      openHappened.fulfill()
    }
    waitForExpectations(timeout: 20, handler: nil)
  }

  func testChallengeStabilityAcrossUnrelatedEdits() {
    do {
      let database = try makeAndOpenEmptyDatabase()
      defer {
        try? FileManager.default.removeItem(at: database.fileURL)
      }
      let originalText = """
      # Shakespeare quotes

      > To be, or not to be, that is the question. (Hamlet)

      """
      let modifiedText = originalText.appending("> Out, out, damn spot! (Macbeth)\n")
      let noteIdentifier = try database.createNote(Note(markdown: originalText, parsingRules: ParsingRules.commonplace))
      let originalNote = try database.note(noteIdentifier: noteIdentifier)
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        XCTAssertEqual(note.challengeTemplates.count, 1)
        note.updateMarkdown(modifiedText, parsingRules: ParsingRules.commonplace)
        XCTAssertEqual(note.challengeTemplates.count, 2)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      XCTAssertEqual(originalNote.challengeTemplates[0].templateIdentifier, modifiedNote.challengeTemplates[0].templateIdentifier)
      XCTAssertEqual(2, modifiedNote.challengeTemplates.count)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testBuryRelatedChallenges() {
    do {
      let database = try makeAndOpenEmptyDatabase()
      defer {
        try? FileManager.default.removeItem(at: database.fileURL)
      }
      _ = try database.createNote(Note.multipleClozes)
      // New items aren't eligible for at 3-5 days.
      let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
      var studySession = database.synchronousStudySession(date: future)
      XCTAssertEqual(studySession.count, 2)
      studySession.ensureUniqueChallengeTemplates()
      XCTAssertEqual(studySession.count, 1)
      while studySession.currentCard != nil {
        studySession.recordAnswer(correct: true)
      }
      try database.updateStudySessionResults(studySession, on: future, buryRelatedChallenges: true)
      studySession = database.synchronousStudySession(date: future)
      XCTAssertEqual(studySession.count, 0)
      studySession = database.synchronousStudySession(date: future.addingTimeInterval(24 * .hour))
      XCTAssertEqual(studySession.count, 1)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private extension NoteSqliteStorageTests {
  @discardableResult
  func makeAndOpenEmptyDatabase(autosaveTimeInterval: TimeInterval = 0.5) throws -> NoteSqliteStorage {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteSqliteStorage(fileURL: fileURL, parsingRules: ParsingRules.commonplace, autosaveTimeInterval: autosaveTimeInterval)
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

  """, parsingRules: ParsingRules.commonplace)

  static let multipleClozes = Note(markdown: "* This ?[](challenge) has multiple ?[](clozes).", parsingRules: ParsingRules.commonplace)
}
