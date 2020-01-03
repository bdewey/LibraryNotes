// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBookApp
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
}
