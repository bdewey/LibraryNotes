// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import BookKit
import Combine
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

  func testMakePlanRecommendsMergeForExactTitleAuthorMatch() throws {
    let inputDirectory = try makeTemporaryDirectory()
    try """
    ---
    title: "War and Peace"
    authors:
      - "Leo Tolstoy"
    year-published: 1865
    catalog-ids:
      openlibrary-work: OL267171W
    ---

    Imported body
    """.write(to: inputDirectory.appendingPathComponent("war-and-peace.md"), atomically: true, encoding: .utf8)

    let database = try makeDatabase()
    let existingNoteID = try database.createNote(makeBookNote(title: "War and Peace", authors: ["Leo Tolstoy"], text: "Existing body"))

    let plan = try BookNoteMarkdownImporter.makePlan(from: inputDirectory, against: database)

    let item = try XCTUnwrap(plan.items.first)
    XCTAssertEqual(item.sourceFile, "war-and-peace.md")
    XCTAssertEqual(item.importedBook.catalogIDs["openlibrary-work"], "OL267171W")
    XCTAssertEqual(item.candidates.map(\.noteID), [existingNoteID])
    XCTAssertEqual(item.candidates.map(\.confidence), [.exactTitleAuthor])
    XCTAssertEqual(item.recommendedAction, .merge(noteID: existingNoteID))
    XCTAssertEqual(item.action, .merge(noteID: existingNoteID))
  }

  func testPlanRoundTripsThroughJSON() throws {
    let plan = BookNoteImportPlan(createdAt: Date(timeIntervalSince1970: 0), items: [
      BookNoteImportPlanItem(
        sourceFile: "war-and-peace.md",
        importedBook: PlannedBookMetadata(title: "War and Peace", authors: ["Leo Tolstoy"]),
        candidates: [
          BookNoteMergeCandidate(
            noteID: "existing-note",
            title: "War and Peace",
            authors: ["Leo Tolstoy"],
            yearPublished: 1865,
            confidence: .exactTitleAuthor,
            score: 1
          ),
        ],
        recommendedAction: .merge(noteID: "existing-note"),
        action: .skip
      ),
    ])
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try encoder.encode(plan)
    let decodedPlan = try decoder.decode(BookNoteImportPlan.self, from: data)

    XCTAssertEqual(decodedPlan, plan)
  }

  func testExecutePlanMergesIntoExistingNote() throws {
    let inputDirectory = try makeTemporaryDirectory()
    try """
    ---
    title: "War and Peace"
    authors:
      - "Leo Tolstoy"
    year-published: 1865
    reading-history:
      - 2025
    ---

    Imported body
    """.write(to: inputDirectory.appendingPathComponent("war-and-peace.md"), atomically: true, encoding: .utf8)

    let database = try makeDatabase()
    let existingNoteID = try database.createNote(makeBookNote(
      title: "War and Peace",
      authors: ["Leo Tolstoy"],
      yearRead: 2024,
      text: "Existing body"
    ))
    let plan = BookNoteImportPlan(items: [
      BookNoteImportPlanItem(
        sourceFile: "war-and-peace.md",
        importedBook: PlannedBookMetadata(title: "War and Peace", authors: ["Leo Tolstoy"]),
        candidates: [],
        recommendedAction: .merge(noteID: existingNoteID),
        action: .merge(noteID: existingNoteID)
      ),
    ])

    let result = try BookNoteMarkdownImporter.execute(plan: plan, from: inputDirectory, into: database)

    XCTAssertEqual(result.items.map(\.noteIdentifier), [existingNoteID])
    XCTAssertEqual(database.noteCount, 1)
    let note = try database.note(noteIdentifier: existingNoteID)
    XCTAssertEqual(note.text, "Existing body\n\n## Imported Notes\n\nSource: war-and-peace.md\n\nImported body")
    XCTAssertEqual(note.metadata.book?.readingHistory?.entries?.compactMap(\.finish?.year), [2024, 2025])
  }

  func testGroupedYearReadQueryReturnsOneRecordPerNotePerYear() throws {
    let database = try makeDatabase()
    let noteIdentifier = try database.createNote(makeBookNote(
      title: "War and Peace",
      authors: ["Leo Tolstoy"],
      readingHistoryDates: [
        dateComponents(year: 2025, month: 2, day: 16),
        dateComponents(year: 2025, month: 9),
        dateComponents(year: 2025, month: 10),
        dateComponents(year: 2025, month: 11),
        dateComponents(year: 2025, month: 12),
      ],
      text: "Body"
    ))
    let records = try waitForNoteIdentifiers(
      in: database,
      groupByYearRead: true
    )

    XCTAssertEqual(records.filter { $0.noteIdentifier == noteIdentifier && $0.finishYear == 2025 }.count, 1)
  }

  func testGroupedYearReadQuerySupportsSearch() throws {
    let database = try makeDatabase()
    let matchingNoteIdentifier = try database.createNote(makeBookNote(
      title: "War and Peace",
      authors: ["Leo Tolstoy"],
      readingHistoryDates: [
        dateComponents(year: 2025, month: 9),
        dateComponents(year: 2025, month: 10),
      ],
      text: "Contains borodino"
    ))
    _ = try database.createNote(makeBookNote(
      title: "Other Book",
      authors: ["Other Author"],
      readingHistoryDates: [
        dateComponents(year: 2025),
      ],
      text: "Body"
    ))
    let records = try waitForNoteIdentifiers(
      in: database,
      groupByYearRead: true,
      searchTerm: "borodino"
    )

    XCTAssertEqual(records.map(\.noteIdentifier), [matchingNoteIdentifier])
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

  private func makeBookNote(
    title: String,
    authors: [String],
    yearRead: Int? = nil,
    readingHistoryDates: [DateComponents] = [],
    text: String
  ) -> Note {
    var book = AugmentedBook(book: Book(title: title, authors: authors))
    if let yearRead {
      var readingHistory = ReadingHistory()
      var components = DateComponents()
      components.year = yearRead
      readingHistory.finishReading(finishDate: components)
      book.readingHistory = readingHistory
    } else if !readingHistoryDates.isEmpty {
      var readingHistory = ReadingHistory()
      for date in readingHistoryDates {
        readingHistory.finishReading(finishDate: date)
      }
      book.readingHistory = readingHistory
    }
    return Note(
      metadata: BookNoteMetadata(
        title: title,
        creationTimestamp: Date(timeIntervalSince1970: 0),
        modifiedTimestamp: Date(timeIntervalSince1970: 0),
        book: book
      ),
      referencedImageKeys: [],
      text: text,
      promptCollections: [:]
    )
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    temporaryDirectories.append(directory)
    return directory
  }

  private func dateComponents(year: Int, month: Int? = nil, day: Int? = nil) -> DateComponents {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return components
  }

  private func waitForNoteIdentifiers(in database: NoteDatabase, groupByYearRead: Bool, searchTerm: String? = nil) throws -> [NoteIdentifierRecord] {
    let expectation = XCTestExpectation(description: "Fetch note identifiers")
    var records: [NoteIdentifierRecord]?
    var receivedError: Error?
    let cancellable = database.noteIdentifiersPublisher(
      structureIdentifier: .read,
      sortOrder: .dateRead,
      groupByYearRead: groupByYearRead,
      searchTerm: searchTerm
    )
    .sink(receiveCompletion: { completion in
      if case .failure(let error) = completion {
        receivedError = error
        expectation.fulfill()
      }
    }, receiveValue: { value in
      records = value
      expectation.fulfill()
    })
    defer {
      cancellable.cancel()
    }
    wait(for: [expectation], timeout: 2)
    if let receivedError {
      throw receivedError
    }
    return try XCTUnwrap(records)
  }
}
