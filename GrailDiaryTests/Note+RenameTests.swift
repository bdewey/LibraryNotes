// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GrailDiary
import XCTest

final class NoteRenameTests: NoteSqliteStorageTestBase {
  func testRenamePreservesPromptHistory() {
    makeAndOpenEmptyDatabase { database in
      do {
        let identifier = try database.createNote(.withChallenges)
        XCTAssertTrue(try database.note(noteIdentifier: identifier).hashtags.contains("#test"))
        XCTAssertFalse(try database.note(noteIdentifier: identifier).hashtags.contains("#testing"))
        let promptIdentifiers = Set(try database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
        try database.replaceText("#test", with: "#testing", filter: { _ in true })
        XCTAssertTrue(try database.note(noteIdentifier: identifier).hashtags.contains("#testing"))
        XCTAssertFalse(try database.note(noteIdentifier: identifier).hashtags.contains("#test"))
        let newPromptIdentifiers = Set(try database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
        XCTAssertEqual(promptIdentifiers, newPromptIdentifiers)
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testRenameHashtagAsAtomicToken() {
    makeAndOpenEmptyDatabase { database in
      do {
        let note1 = try database.createNote(Note(markdown: "First note #book"))
        let note2 = try database.createNote(Note(markdown: "Second note #books"))
        XCTAssertTrue(try database.note(noteIdentifier: note2).hashtags.contains("#books"))
        try database.renameHashtag("#book", to: "#books", filter: { _ in true })
        XCTAssertFalse(try database.note(noteIdentifier: note1).hashtags.contains("#book"))
        XCTAssertTrue(try database.note(noteIdentifier: note1).hashtags.contains("#books"))
        XCTAssertTrue(try database.note(noteIdentifier: note2).hashtags.contains("#books"))
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
