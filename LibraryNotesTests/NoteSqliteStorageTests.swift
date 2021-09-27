// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import KeyValueCRDT
@testable import LibraryNotes
import XCTest

final class NoteSqliteStorageTests: XCTestCase {
  private var database: NoteDatabase!

  override func setUp() async throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    database = try await NoteDatabase(fileURL: fileURL, authorDescription: "test")
  }

  override func tearDown() async throws {
    _ = await database.close()
    try FileManager.default.removeItem(at: database.fileURL)
  }

  func testRoundTripSimpleNoteContents() async throws {
    let identifier = try database.createNote(Note.simpleTest)
    XCTAssertTrue(database.hasUnsavedChanges)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.simpleTest, roundTripNote)
  }

  func testUpdateNonExistantNoteCreatesNote() async throws {
    var note = Note.simpleTest
    let identifier = UUID().uuidString
    try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in
      note
    })
    note.text = "Version 2.0 text"
    try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in note })
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(note, roundTripNote)
  }

  func testUpdateSimpleNote() async throws {
    var note = Note.simpleTest
    let identifier = try database.createNote(note)
    note.text = "Version 2.0 text"
    try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in note })
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(note, roundTripNote)
  }

  func testRoundTripHashtagNoteContents() async throws {
    let identifier = try database.createNote(Note.withHashtags)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.withHashtags, roundTripNote)
  }

  func testRoundTripReferenceWebPage() async throws {
    let identifier = try database.createNote(.withReferenceWebPage)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.withReferenceWebPage, roundTripNote)
  }

  func testUpdateHashtags() async throws {
    let identifier = try database.createNote(Note.withHashtags)
    try database.updateNote(noteIdentifier: identifier, updateBlock: { oldNote -> Note in
      var note = oldNote
      note.metadata.tags = ["#updated"]
      return note
    })
    XCTAssertTrue(database.hasUnsavedChanges)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    var expectedNote = Note.withHashtags
    expectedNote.metadata.tags = ["#updated"]
    XCTAssertEqual(expectedNote, roundTripNote)
  }

  func testUpdateNoteWithChallenges() async throws {
    let identifier = try database.createNote(Note.withChallenges)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.withChallenges, roundTripNote)
    XCTAssertEqual(roundTripNote.promptCollections.count, 3)
  }

  func testPartialQuoteDoesntFail() async throws {
    let note = Note(markdown: """
    # Title
    >

    """)
    let identifier = try database.createNote(note)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(note, roundTripNote)
    XCTAssertEqual(roundTripNote.promptCollections.count, 1)
  }

  func testRemoveChallengesFromNote() async throws {
    let identifier = try database.createNote(Note.withChallenges)
    try database.updateNote(noteIdentifier: identifier, updateBlock: { _ in Note.simpleTest })
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.simpleTest, roundTripNote)
  }

  func testCreatingNoteSendsNotification() async throws {
    var didGetNotification = false
    let cancellable = database.notesDidChange.sink { didGetNotification = true }
    _ = try database.createNote(Note.simpleTest)
    XCTAssertTrue(didGetNotification)
    cancellable.cancel()
  }

  func testDeleteNote() async throws {
    let identifier = try database.createNote(Note.withHashtags)
    let roundTripNote = try database.note(noteIdentifier: identifier)
    XCTAssertEqual(Note.withHashtags, roundTripNote)
    XCTAssertEqual(1, database.noteCount)
    try database.deleteNote(noteIdentifier: identifier)
    XCTAssertTrue(database.hasUnsavedChanges)
    XCTAssertThrowsError(try database.note(noteIdentifier: identifier))
    XCTAssertEqual(0, database.noteCount)
  }

  func testStudyLog() async throws {
    _ = try database.createNote(Note.withChallenges)
    // New items aren't eligible for at 3-5 days.
    let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
    var studySession = try await database.studySession(filter: nil, date: future)
    XCTAssertEqual(3, studySession.count)
    while studySession.currentPrompt != nil {
      studySession.recordAnswer(correct: true)
    }
    try database.updateStudySessionResults(studySession, on: Date(), buryRelatedPrompts: true)
    XCTAssertTrue(database.hasUnsavedChanges)
    XCTAssertEqual(database.studyLog.count, studySession.count)
  }

  func testStudySessionWithIncorrectLearningItems() async throws {
    _ = try database.createNote(Note.withChallenges)
    // New items aren't eligible for at 3-5 days.
    let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
    var studySession = try await database.studySession(filter: nil, date: future)
    XCTAssertEqual(3, studySession.count)
    var expectedIncorrectAnswers = 3
    while studySession.currentPrompt != nil {
      if expectedIncorrectAnswers > 0 {
        expectedIncorrectAnswers -= 1
        studySession.recordAnswer(correct: false)
      } else {
        studySession.recordAnswer(correct: true)
      }
    }
    // No asserts needed -- this test passes if this doesn't throw an error.
    try database.updateStudySessionResults(studySession, on: Date(), buryRelatedPrompts: true)
  }

  func testChallengeStabilityAcrossUnrelatedEdits() async throws {
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

  func testChallengeStabilityWithTemplateEdits() async throws {
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

  func testSubstantialEditGetsNewKey() async throws {
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

  func testBuryRelatedChallenges() async throws {
    _ = try database.createNote(Note.multipleClozes)
    // New items aren't eligible for at 3-5 days.
    let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
    var studySession = try await database.studySession(filter: nil, date: future)
    XCTAssertEqual(studySession.count, 2)
    studySession.ensureUniquePromptCollections()
    XCTAssertEqual(studySession.count, 1)
    while studySession.currentPrompt != nil {
      studySession.recordAnswer(correct: true)
    }
    try database.updateStudySessionResults(studySession, on: future, buryRelatedPrompts: true)
    studySession = try await database.studySession(filter: nil, date: future)
    XCTAssertEqual(studySession.count, 0)
    studySession = try await database.studySession(filter: nil, date: future.addingTimeInterval(24 * .hour))
    XCTAssertEqual(studySession.count, 1)
  }
}
