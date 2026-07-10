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

  func testSnapshotRoundTrip() throws {
    let snapshot = QuoteOfTheDaySnapshot(
      sourceLibraryDisplayName: "Fixture Library",
      cacheTimestamp: Date(timeIntervalSince1970: 1800000000),
      candidates: [
        QuoteWidgetCandidate(
          noteId: "note-1",
          quoteKey: "prompt=quote:abc",
          quoteText: "The answer is not in the back of the book.",
          attributionText: "Thinking Fast and Slow, 80",
          sourceTitle: "Thinking Fast and Slow",
          thumbnailImage: Data([0x01, 0x02, 0x03]),
          selectedText: "The answer is not in the back of the book. (80)",
          tags: ["psychology"]
        ),
      ]
    )
    let data = try JSONEncoder().encode(snapshot)

    let decoded = try JSONDecoder().decode(QuoteOfTheDaySnapshot.self, from: data)

    XCTAssertEqual(decoded, snapshot)
    XCTAssertTrue(decoded.isReadableByCurrentVersion)
  }

  func testStoreReadsAndWritesSnapshotInContainer() throws {
    let containerURL = try makeTemporaryDirectory()
    let store = QuoteWidgetStore(containerURL: containerURL)
    let snapshot = QuoteOfTheDaySnapshot(
      sourceLibraryDisplayName: "Fixture Library",
      cacheTimestamp: Date(timeIntervalSince1970: 1800000000),
      candidates: [
        QuoteWidgetCandidate(
          noteId: "note-1",
          quoteKey: "quote-1",
          quoteText: "A cached quote.",
          attributionText: "Cached Book",
          sourceTitle: "Cached Book"
        ),
      ]
    )

    try store.writeSnapshot(snapshot)

    XCTAssertEqual(store.snapshotURL, containerURL.appendingPathComponent(QuoteWidgetStore.snapshotFileName))
    XCTAssertEqual(try store.readSnapshot(), snapshot)
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

  func testMissingSnapshotThrows() throws {
    let store = try QuoteWidgetStore(containerURL: makeTemporaryDirectory())
    let snapshotURL = try XCTUnwrap(store.snapshotURL)

    XCTAssertThrowsError(try store.readSnapshot()) { error in
      XCTAssertEqual(error as? QuoteWidgetStoreError, .missingSnapshot(snapshotURL))
    }
  }

  func testUnsupportedSchemaVersionThrows() throws {
    let containerURL = try makeTemporaryDirectory()
    let store = QuoteWidgetStore(containerURL: containerURL)
    let snapshot = QuoteOfTheDaySnapshot(
      schemaVersion: QuoteOfTheDaySnapshot.currentSchemaVersion + 1,
      sourceLibraryDisplayName: "Future Library",
      cacheTimestamp: Date(timeIntervalSince1970: 1800000000),
      candidates: []
    )
    try store.writeSnapshot(snapshot)

    XCTAssertThrowsError(try store.readSnapshot()) { error in
      XCTAssertEqual(error as? QuoteWidgetStoreError, .unsupportedSchemaVersion(snapshot.schemaVersion))
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
