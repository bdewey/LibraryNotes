// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
@testable import LibraryNotesCore
import XCTest

final class BookNoteMarkdownImporterTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDown() {
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
  }

  func testImportsMarkdownBookNote() throws {
    let inputDirectory = try makeTemporaryDirectory()
    let markdownURL = inputDirectory.appendingPathComponent("example.md")
    try """
    ---
    title: "Example Book"
    authors:
      - "Ada Lovelace"
      - "Grace Hopper"
    year-published: 1843
    rating: 5
    reading-history:
      - 2024-06-18
      - 2025
    catalog-ids:
      openlibrary-work: OL123W
    ---

    Notes, quotes, and #history

    Q: Who wrote it?
    A: Ada and Grace.
    """.write(to: markdownURL, atomically: true, encoding: .utf8)

    let database = try makeDatabase()
    let result = try BookNoteMarkdownImporter.import(from: inputDirectory, into: database)

    XCTAssertEqual(result.items.count, 1)
    let item = try XCTUnwrap(result.items.first)
    let noteIdentifier = try XCTUnwrap(item.noteIdentifier)
    let note = try database.note(noteIdentifier: noteIdentifier)
    let book = try XCTUnwrap(note.metadata.book)
    XCTAssertEqual(book.title, "Example Book")
    XCTAssertEqual(book.authors, ["Ada Lovelace", "Grace Hopper"])
    XCTAssertEqual(book.originalYearPublished, 1843)
    XCTAssertEqual(book.rating, 5)
    XCTAssertEqual(book.readingHistory?.entries?.compactMap(\.finish?.year), [2024, 2025])
    XCTAssertEqual(note.metadata.tags, ["#history"])
    XCTAssertEqual(note.text, "Notes, quotes, and #history\n\nQ: Who wrote it?\nA: Ada and Grace.")
  }

  func testImportsEmptyAuthorList() throws {
    let inputDirectory = try makeTemporaryDirectory()
    try """
    ---
    title: "Untitled Lecture"
    authors: []
    ---

    Body
    """.write(to: inputDirectory.appendingPathComponent("lecture.md"), atomically: true, encoding: .utf8)

    let database = try makeDatabase()
    let result = try BookNoteMarkdownImporter.import(from: inputDirectory, into: database)
    let noteIdentifier = try XCTUnwrap(result.items.first?.noteIdentifier)
    let note = try database.note(noteIdentifier: noteIdentifier)

    XCTAssertEqual(note.metadata.book?.authors, [])
  }

  func testDryRunDoesNotCreateNotes() throws {
    let inputDirectory = try makeTemporaryDirectory()
    try """
    ---
    title: "Preview"
    authors:
      - "Author"
    ---

    Body
    """.write(to: inputDirectory.appendingPathComponent("preview.md"), atomically: true, encoding: .utf8)

    let database = try makeDatabase()
    let result = try BookNoteMarkdownImporter.import(
      from: inputDirectory,
      into: database,
      options: BookNoteMarkdownImportOptions(dryRun: true)
    )

    XCTAssertEqual(result.items.map(\.title), ["Preview"])
    XCTAssertEqual(result.items.map(\.noteIdentifier), [nil])
    XCTAssertEqual(database.noteCount, 0)
  }

  func testMissingFrontmatterThrows() throws {
    let inputDirectory = try makeTemporaryDirectory()
    let markdownURL = inputDirectory.appendingPathComponent("plain.md")
    try "Body".write(to: markdownURL, atomically: true, encoding: .utf8)
    let database = try makeDatabase()

    XCTAssertThrowsError(try BookNoteMarkdownImporter.import(from: inputDirectory, into: database)) { error in
      guard case .missingFrontmatter(let url) = error as? BookNoteMarkdownImportError else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(url.standardizedFileURL.path, markdownURL.standardizedFileURL.path)
    }
  }

  private func makeDatabase() throws -> NoteDatabase {
    let fileURL = try makeTemporaryDirectory().appendingPathComponent("library.libnotes")
    return try NoteDatabase(fileURL: fileURL, authorDescription: "test")
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    temporaryDirectories.append(directory)
    return directory
  }
}
