// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import KeyValueCRDT
@testable import LibraryNotesCore
import XCTest

final class BookNoteMarkdownExporterTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDown() {
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
  }

  func testBookFrontmatterQuotesStringScalars() {
    let book = AugmentedBook(
      book: Book(
        title: "In Defense of Food: An Eater's Manifesto",
        authors: [
          "Pollan: Michael",
          #"Author "With Quotes""#,
        ],
        yearPublished: 2008
      ),
      rating: 5
    )

    XCTAssertEqual(
      BookNoteMarkdownExporter.frontmatter(for: book),
      """
      ---
      title: "In Defense of Food: An Eater's Manifesto"
      authors:
      - "Pollan: Michael"
      - "Author \\"With Quotes\\""
      year-published: 2008
      rating: 5
      ---


      """
    )
  }

  func testBookFrontmatterIncludesReadingHistory() {
    var book = AugmentedBook(
      book: Book(
        title: "A Read Book",
        authors: ["Reader"],
        yearPublished: 2020
      )
    )
    var readingHistory = ReadingHistory()
    readingHistory.finishReading(finishDate: dateComponents(year: 2024, month: 6, day: 18))
    readingHistory.finishReading(finishDate: dateComponents(year: 2025))
    book.readingHistory = readingHistory

    XCTAssertEqual(
      BookNoteMarkdownExporter.frontmatter(for: book),
      """
      ---
      title: "A Read Book"
      authors:
      - "Reader"
      year-published: 2020
      reading-history:
      - 2024-06-18
      - 2025
      ---


      """
    )
  }

  func testDefaultExportIncludesOnlyNonTrashBookNotes() throws {
    let database = try makeDatabase()
    _ = try database.createNote(makeBookNote(title: "Included", authors: ["Author"]))
    _ = try database.createNote(makeNonBookNote(title: "Plain Note"))
    _ = try database.createNote(makeBookNote(title: "Deleted", authors: ["Author"], folder: PredefinedFolder.recentlyDeleted.rawValue))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")

    let plan = try BookNoteMarkdownExporter.export(from: database, to: outputURL)

    XCTAssertEqual(plan.items.map(\.markdownURL.lastPathComponent), ["included-author.md"])
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("included-author.md").path))
  }

  func testSelectionFilters() throws {
    let database = try makeDatabase()
    let matchingID = try database.createNote(makeBookNote(
      title: "Matching Book",
      authors: ["Jane Writer"],
      metadataTags: ["#fiction"],
      bookTags: ["#award"],
      yearRead: 2024
    ))
    _ = try database.createNote(makeBookNote(
      title: "Wrong Year",
      authors: ["Jane Writer"],
      metadataTags: ["#fiction"],
      bookTags: ["#award"],
      yearRead: 2023
    ))
    _ = try database.createNote(makeBookNote(
      title: "Wrong Tag",
      authors: ["Jane Writer"],
      metadataTags: ["#memoir"],
      bookTags: ["#award"],
      yearRead: 2024
    ))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")

    let selection = BookNoteExportSelection(
      hashtags: ["fiction"],
      yearsRead: [2024],
      titleQueries: ["match"],
      authorQueries: ["writer"],
      noteIDs: [matchingID]
    )
    let plan = try BookNoteMarkdownExporter.export(from: database, to: outputURL, selection: selection)

    XCTAssertEqual(plan.items.map(\.noteIdentifier), [matchingID])
    XCTAssertEqual(plan.items.map(\.markdownURL.lastPathComponent), ["matching-book-jane-writer.md"])
  }

  func testSearchFilterMatchesNoteBody() throws {
    let database = try makeDatabase()
    let matchingID = try database.createNote(makeBookNote(title: "One", authors: ["Author"], text: "contains special phrase"))
    _ = try database.createNote(makeBookNote(title: "Two", authors: ["Author"], text: "other text"))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")

    let plan = try BookNoteMarkdownExporter.export(
      from: database,
      to: outputURL,
      selection: BookNoteExportSelection(searchQuery: "special phrase")
    )

    XCTAssertEqual(plan.items.map(\.noteIdentifier), [matchingID])
  }

  func testFilenameCollisionsAreDeterministic() throws {
    let database = try makeDatabase()
    _ = try database.createNote(makeBookNote(title: "Same", authors: ["Author"]))
    _ = try database.createNote(makeBookNote(title: "Same", authors: ["Author"]))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")

    let plan = try BookNoteMarkdownExporter.export(from: database, to: outputURL)

    XCTAssertEqual(plan.items.map(\.markdownURL.lastPathComponent), ["same-author.md", "same-author-1.md"])
  }

  func testCoverImageExportAndNoAssets() throws {
    let database = try makeDatabase()
    let noteID = try database.createNote(makeBookNote(title: "Covered", authors: ["Author"]))
    try database.writeValue(
      .blob(mimeType: "image/jpeg", blob: Data([0xFF, 0xD8, 0xFF])),
      noteIdentifier: noteID,
      key: .coverImage
    )

    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")
    let plan = try BookNoteMarkdownExporter.export(from: database, to: outputURL)

    let item = try XCTUnwrap(plan.items.first)
    let assetURL = try XCTUnwrap(item.assetURL)
    let markdown = try String(contentsOf: item.markdownURL, encoding: .utf8)
    XCTAssertTrue(FileManager.default.fileExists(atPath: assetURL.path))
    XCTAssertTrue(markdown.contains("![Book cover](covered-author/coverImage."))

    let noAssetsURL = try makeTemporaryDirectory().appendingPathComponent("export-no-assets")
    let noAssetsPlan = try BookNoteMarkdownExporter.export(
      from: database,
      to: noAssetsURL,
      options: BookNoteMarkdownExportOptions(includeAssets: false)
    )
    let noAssetsItem = try XCTUnwrap(noAssetsPlan.items.first)
    let noAssetsMarkdown = try String(contentsOf: noAssetsItem.markdownURL, encoding: .utf8)
    XCTAssertNil(noAssetsItem.assetURL)
    XCTAssertFalse(noAssetsMarkdown.contains("![Book cover]"))
  }

  func testOverwriteProtection() throws {
    let database = try makeDatabase()
    _ = try database.createNote(makeBookNote(title: "Existing", authors: ["Author"]))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    try "existing".write(to: outputURL.appendingPathComponent("existing-author.md"), atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try BookNoteMarkdownExporter.export(from: database, to: outputURL)) { error in
      XCTAssertEqual(error as? BookNoteMarkdownExportError, .outputCollision(outputURL.appendingPathComponent("existing-author.md")))
    }

    XCTAssertNoThrow(try BookNoteMarkdownExporter.export(
      from: database,
      to: outputURL,
      options: BookNoteMarkdownExportOptions(overwrite: true)
    ))
  }

  func testDryRunDoesNotWriteFiles() throws {
    let database = try makeDatabase()
    _ = try database.createNote(makeBookNote(title: "Preview", authors: ["Author"]))
    let outputURL = try makeTemporaryDirectory().appendingPathComponent("export")

    let plan = try BookNoteMarkdownExporter.export(
      from: database,
      to: outputURL,
      options: BookNoteMarkdownExportOptions(dryRun: true)
    )

    XCTAssertEqual(plan.items.map(\.markdownURL.lastPathComponent), ["preview-author.md"])
    XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
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

  private func makeBookNote(
    title: String,
    authors: [String],
    metadataTags: [String] = [],
    bookTags: [String] = [],
    yearRead: Int? = nil,
    folder: String? = nil,
    text: String = "Body"
  ) -> Note {
    var book = AugmentedBook(book: Book(title: title, authors: authors))
    if !bookTags.isEmpty {
      book.tags = bookTags
    }
    if let yearRead {
      var readingHistory = ReadingHistory()
      readingHistory.finishReading(finishDate: dateComponents(year: yearRead))
      book.readingHistory = readingHistory
    }
    return Note(
      metadata: BookNoteMetadata(
        title: title,
        creationTimestamp: Date(timeIntervalSince1970: 0),
        modifiedTimestamp: Date(timeIntervalSince1970: 0),
        tags: metadataTags,
        folder: folder,
        book: book
      ),
      referencedImageKeys: [],
      text: text,
      promptCollections: [:]
    )
  }

  private func makeNonBookNote(title: String) -> Note {
    Note(
      metadata: BookNoteMetadata(
        title: title,
        creationTimestamp: Date(timeIntervalSince1970: 0),
        modifiedTimestamp: Date(timeIntervalSince1970: 0)
      ),
      referencedImageKeys: [],
      text: "Body",
      promptCollections: [:]
    )
  }

  private func dateComponents(year: Int, month: Int? = nil, day: Int? = nil) -> DateComponents {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return components
  }
}
