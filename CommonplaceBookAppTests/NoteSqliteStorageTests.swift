// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
@testable import CommonplaceBookApp
import MiniMarkdown
import XCTest

final class NoteSqliteStorageTests: XCTestCase {
  func testCanOpenNonexistantFile() {
    makeAndOpenEmptyDatabase { _ in
      // NOTHING
    }
  }

  func testRoundTripSimpleNoteContents() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.simpleTest)
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.simpleTest, roundTripNote)
    }
  }

  func testUpdateSimpleNote() {
    makeAndOpenEmptyDatabase { database in
      var note = Note.simpleTest
      let identifier = try database.createNote(note)
      note.text = "Version 2.0 text"
      try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in note })
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(note, roundTripNote)
    }
  }

  func testRoundTripHashtagNoteContents() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withHashtags)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withHashtags, roundTripNote)
    }
  }

  func testUpdateHashtags() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withHashtags)
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
    }
  }

  func testUpdateNoteWithChallenges() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withChallenges)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withChallenges, roundTripNote)
      XCTAssertEqual(roundTripNote.challengeTemplates.count, 3)
    }
  }

  func testPartialQuoteDoesntFail() {
    let note = Note(markdown: """
    # Title
    >

    """)
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(note)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(note, roundTripNote)
      XCTAssertEqual(roundTripNote.challengeTemplates.count, 1)
    }
  }

  func testRemoveChallengesFromNote() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withChallenges)
      try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in Note.simpleTest })
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.simpleTest, roundTripNote)
    }
  }

  func testNotesShowUpInAllMetadata() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withHashtags)
      XCTAssertEqual(1, database.allMetadata.count)
      XCTAssertEqual(database.allMetadata[identifier], Note.withHashtags.metadata)
    }
  }

  func testCreatingNoteSendsNotification() {
    makeAndOpenEmptyDatabase { database in
      var didGetNotification = false
      let cancellable = database.notesDidChange.sink { didGetNotification = true }
      _ = try database.createNote(Note.simpleTest)
      XCTAssertTrue(didGetNotification)
      cancellable.cancel()
    }
  }

  func testDeleteNote() {
    makeAndOpenEmptyDatabase { database in
      let identifier = try database.createNote(Note.withHashtags)
      let roundTripNote = try database.note(noteIdentifier: identifier)
      XCTAssertEqual(Note.withHashtags, roundTripNote)
      XCTAssertEqual(1, database.allMetadata.count)
      try database.deleteNote(noteIdentifier: identifier)
      XCTAssertTrue(database.hasUnsavedChanges)
      XCTAssertThrowsError(try database.note(noteIdentifier: identifier))
      XCTAssertEqual(0, try database.countOfTextRows())
      XCTAssertEqual(0, database.allMetadata.count)
    }
  }

  func testStoreData() {
    makeAndOpenEmptyDatabase { database in
      let data = "Hello, world!".data(using: .utf8)!
      let key = try database.storeAssetData(data, key: "test.txt")
      XCTAssertTrue(database.hasUnsavedChanges)
      let roundTrip = try database.data(for: key)
      XCTAssertEqual(data, roundTrip)
    }
  }

  func testStudyLog() {
    makeAndOpenEmptyDatabase { database in
      _ = try database.createNote(Note.withChallenges)
      // New items aren't eligible for at 3-5 days.
      let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
      var studySession = database.synchronousStudySession(date: future)
      XCTAssertEqual(3, studySession.count)
      while studySession.currentCard != nil {
        studySession.recordAnswer(correct: true)
      }
      try database.updateStudySessionResults(studySession, on: Date(), buryRelatedChallenges: true)
      XCTAssertTrue(database.hasUnsavedChanges)
      XCTAssertEqual(database.studyLog.count, studySession.count)
    }
  }

  func testChallengeStabilityAcrossUnrelatedEdits() {
    makeAndOpenEmptyDatabase { database in
      let originalText = """
      # Shakespeare quotes

      > To be, or not to be, that is the question. (Hamlet)

      """
      let modifiedText = originalText.appending("> Out, out, damn spot! (Macbeth)\n")
      let noteIdentifier = try database.createNote(Note(markdown: originalText))
      let originalNote = try database.note(noteIdentifier: noteIdentifier)
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        XCTAssertEqual(note.challengeTemplates.count, 1)
        note.updateMarkdown(modifiedText)
        XCTAssertEqual(note.challengeTemplates.count, 2)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      XCTAssertEqual(originalNote.challengeTemplates[0].templateIdentifier, modifiedNote.challengeTemplates[0].templateIdentifier)
      XCTAssertEqual(2, modifiedNote.challengeTemplates.count)
    }
  }

  func testChallengeStabilityWithTemplateEdits() {
    makeAndOpenEmptyDatabase { database in
      let originalText = """
      # Shakespeare quotes

      > To be, or not to be, that is the question.
      """
      let modifiedText = originalText.appending(" (Hamlet)\n")
      let noteIdentifier = try database.createNote(Note(markdown: originalText))
      let originalNote = try database.note(noteIdentifier: noteIdentifier)
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        XCTAssertEqual(note.challengeTemplates.count, 1)
        note.updateMarkdown(modifiedText)
        XCTAssertEqual(note.challengeTemplates.count, 1)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      XCTAssertEqual(originalNote.challengeTemplates[0].templateIdentifier, modifiedNote.challengeTemplates[0].templateIdentifier)
      XCTAssertEqual(1, modifiedNote.challengeTemplates.count)
      XCTAssertEqual(modifiedNote.challengeTemplates[0].rawValue, "> To be, or not to be, that is the question. (Hamlet)\n")
    }
  }

  func testBuryRelatedChallenges() {
    makeAndOpenEmptyDatabase { database in
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
    }
  }
}

private extension NoteSqliteStorageTests {
  func makeAndOpenEmptyDatabase(completion: @escaping (NoteSqliteStorage) throws -> Void) {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteSqliteStorage(fileURL: fileURL, parsingRules: ParsingRules.commonplace)
    let completionExpectation = expectation(description: "Expected to call completion routine")
    database.open { success in
      if success {
        do {
          try completion(database)
        } catch {
          XCTFail("Unexpected error: \(error)")
        }
      } else {
        XCTFail("Could not open database")
      }
      completionExpectation.fulfill()
    }
    waitForExpectations(timeout: 5, handler: nil)
    let closedExpectation = expectation(description: "Can close")
    database.close { _ in
      try? FileManager.default.removeItem(at: database.fileURL)
      closedExpectation.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}
