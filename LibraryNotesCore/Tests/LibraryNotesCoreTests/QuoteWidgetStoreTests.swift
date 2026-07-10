// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

@testable import LibraryNotesCore
import XCTest

final class QuoteWidgetStoreTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDown() {
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
  }

  func testStoreReadsOnlyRequestedCandidatesFromDatabase() throws {
    let containerURL = try makeTemporaryDirectory()
    let store = QuoteWidgetStore(containerURL: containerURL)
    let candidates = [
      QuoteWidgetCandidate(
        noteId: "note-1",
        quoteKey: "quote-1",
        quoteText: "A quote without a cover.",
        attributionText: "Book One",
        sourceTitle: "Book One"
      ),
      QuoteWidgetCandidate(
        noteId: "note-2",
        quoteKey: "quote-2",
        quoteText: "A quote with a cover.",
        attributionText: "Book Two",
        sourceTitle: "Book Two",
        thumbnailImage: Data([0x01, 0x02, 0x03]),
        selectedText: "A quote with a cover. (12)",
        tags: ["fiction"]
      ),
      QuoteWidgetCandidate(
        noteId: "note-3",
        quoteKey: "quote-3",
        quoteText: "Another quote with a cover.",
        attributionText: "Book Three",
        sourceTitle: "Book Three",
        thumbnailImage: Data([0x04, 0x05, 0x06])
      ),
    ]
    try store.replaceQuotes(
      sourceLibraryDisplayName: "Fixture Library",
      cacheTimestamp: Date(timeIntervalSince1970: 1800000000),
      candidates: candidates
    )

    XCTAssertEqual(store.databaseURL, containerURL.appendingPathComponent(QuoteWidgetStore.databaseFileName))
    XCTAssertEqual(try store.readCandidates(limit: 1), [candidates[1]])
    XCTAssertEqual(try store.readCandidates(limit: 2), [candidates[1], candidates[2]])
  }

  func testStoreWritesPreferredLibraryBookmarkInAppGroupDefaults() throws {
    let suiteName = "QuoteWidgetStoreTests.\(UUID().uuidString)"
    let store = try QuoteWidgetStore(appGroupIdentifier: suiteName, containerURL: makeTemporaryDirectory())
    let libraryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Favorite Library")
      .appendingPathExtension("libnotes")
    try Data().write(to: libraryURL)
    defer { try? FileManager.default.removeItem(at: libraryURL) }

    try store.writePreferredLibraryBookmark(for: libraryURL, displayName: "Favorite Library")

    let bookmarkData = try store.preferredLibraryBookmarkData()
    var isStale = false
    let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
    XCTAssertEqual(resolvedURL.standardizedFileURL, libraryURL.standardizedFileURL)
    XCTAssertFalse(isStale)
    XCTAssertEqual(try store.preferredLibraryDisplayName(), "Favorite Library")
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }

  func testCandidateProjectionFromAttributedQuote() {
    let candidate = QuoteWidgetCandidate(AttributedQuote(
      noteId: "note-1",
      key: "prompt=quote:abc",
      text: " The answer is not in the back of the book. (80) ",
      title: "Thinking Fast and Slow",
      thumbnailImage: Data([0x04, 0x05, 0x06])
    ))

    XCTAssertEqual(candidate.noteId, "note-1")
    XCTAssertEqual(candidate.quoteKey, "prompt=quote:abc")
    XCTAssertEqual(candidate.quoteText, "The answer is not in the back of the book.")
    XCTAssertEqual(candidate.attributionText, "Thinking Fast and Slow, 80")
    XCTAssertEqual(candidate.sourceTitle, "Thinking Fast and Slow")
    XCTAssertEqual(candidate.thumbnailImage, Data([0x04, 0x05, 0x06]))
    XCTAssertEqual(candidate.selectedText, " The answer is not in the back of the book. (80) ")
  }

  func testMissingDatabaseThrows() throws {
    let store = try QuoteWidgetStore(containerURL: makeTemporaryDirectory())
    let databaseURL = try XCTUnwrap(store.databaseURL)

    XCTAssertThrowsError(try store.readCandidates(limit: 1)) { error in
      XCTAssertEqual(error as? QuoteWidgetStoreError, .missingDatabase(databaseURL))
    }
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }
}
