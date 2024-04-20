// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import KeyValueCRDT
import Library_Notes
import XCTest

@MainActor
final class NoteRenameTests: XCTestCase {
  private var database: NoteDatabase!

  override func setUp() async throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    database = try await NoteDatabase(fileURL: fileURL, authorDescription: "test")
  }

  override func tearDown() async throws {
    _ = await database.close()
    try FileManager.default.removeItem(at: database.fileURL)
  }

  func testRenamePreservesPromptHistory() async throws {
    let identifier = try database.createNote(.withChallenges)
    XCTAssertTrue(try database.note(noteIdentifier: identifier).metadata.tags.contains("#test"))
    XCTAssertFalse(try database.note(noteIdentifier: identifier).metadata.tags.contains("#testing"))
    let promptIdentifiers = try Set(database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
    try database.replaceText("#test", with: "#testing", filter: { _ in true })
    XCTAssertTrue(try database.note(noteIdentifier: identifier).metadata.tags.contains("#testing"))
    XCTAssertFalse(try database.note(noteIdentifier: identifier).metadata.tags.contains("#test"))
    let newPromptIdentifiers = try Set(database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
    XCTAssertEqual(promptIdentifiers, newPromptIdentifiers)
  }

  func testRenameHashtagAsAtomicToken() async throws {
    let note1 = try database.createNote(Note(markdown: "First note #book"))
    let note2 = try database.createNote(Note(markdown: "Second note #books"))
    XCTAssertTrue(try database.note(noteIdentifier: note2).metadata.tags.contains("#books"))
    try database.renameHashtag("#book", to: "#books", filter: { _ in true })
    XCTAssertFalse(try database.note(noteIdentifier: note1).metadata.tags.contains("#book"))
    XCTAssertTrue(try database.note(noteIdentifier: note1).metadata.tags.contains("#books"))
    XCTAssertTrue(try database.note(noteIdentifier: note2).metadata.tags.contains("#books"))
  }
}
