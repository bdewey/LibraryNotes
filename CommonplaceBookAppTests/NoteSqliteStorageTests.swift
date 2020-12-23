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

import Combine
@testable import CommonplaceBookApp
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
      XCTAssertEqual(roundTripNote.promptCollections.count, 3)
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
      XCTAssertEqual(roundTripNote.promptCollections.count, 1)
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
      while studySession.currentPrompt != nil {
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
      let originalPromptKey = originalNote.promptCollections.first!.key
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        XCTAssertEqual(note.promptCollections.count, 1)
        note.updateMarkdown(modifiedText)
        XCTAssertEqual(note.promptCollections.count, 2)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      XCTAssertEqual(originalNote.promptCollections[originalPromptKey]!.rawValue, modifiedNote.promptCollections[originalPromptKey]!.rawValue)
      XCTAssertEqual(2, modifiedNote.promptCollections.count)
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
        XCTAssertEqual(note.promptCollections.count, 1)
        note.updateMarkdown(modifiedText)
        XCTAssertEqual(note.promptCollections.count, 1)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      XCTAssertEqual(originalNote.promptCollections.keys, modifiedNote.promptCollections.keys)
      XCTAssertEqual(1, modifiedNote.promptCollections.count)
      XCTAssertEqual(modifiedNote.promptCollections.first!.value.rawValue, "> To be, or not to be, that is the question. (Hamlet)\n")
    }
  }

  func testSubstantialEditGetsNewKey() {
    makeAndOpenEmptyDatabase { database in
      let originalText = """
      # Shakespeare quotes

      > To be, or not to be, that is the question.
      """
      let modifiedText = """
      # Shakespeare quotes

      > Out, out, damn spot!
      """
      let noteIdentifier = try database.createNote(Note(markdown: originalText))
      let originalNote = try database.note(noteIdentifier: noteIdentifier)
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        XCTAssertEqual(note.promptCollections.count, 1)
        note.updateMarkdown(modifiedText)
        XCTAssertEqual(note.promptCollections.count, 1)
        return note
      })
      let modifiedNote = try database.note(noteIdentifier: noteIdentifier)
      // We should have *different* keys because we changed the quote substantially, not just a little edit.
      XCTAssertNotEqual(originalNote.promptCollections.keys, modifiedNote.promptCollections.keys)
      XCTAssertEqual(1, modifiedNote.promptCollections.count)
      XCTAssertEqual(modifiedNote.promptCollections.first!.value.rawValue, "> Out, out, damn spot!")
    }
  }

  func testBuryRelatedChallenges() {
    makeAndOpenEmptyDatabase { database in
      _ = try database.createNote(Note.multipleClozes)
      // New items aren't eligible for at 3-5 days.
      let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
      var studySession = database.synchronousStudySession(date: future)
      XCTAssertEqual(studySession.count, 2)
      studySession.ensureUniquePromptCollections()
      XCTAssertEqual(studySession.count, 1)
      while studySession.currentPrompt != nil {
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
  func makeAndOpenEmptyDatabase(completion: @escaping (NoteDatabase) throws -> Void) {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteDatabase(fileURL: fileURL)
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
