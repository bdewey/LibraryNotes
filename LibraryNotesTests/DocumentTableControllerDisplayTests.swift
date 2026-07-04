// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

@testable import Library_Notes
import LibraryNotesCore
import XCTest

final class DocumentTableControllerDisplayTests: XCTestCase {
  @MainActor func testCurrentYearReadRecordIsSuppressedWhenBookIsCurrentlyReading() throws {
    let records = try [
      record("paradise-lost", section: .currentlyReading, startYear: 2026),
      record("paradise-lost", section: .read, finishYear: 2026, startYear: 2026),
    ]

    let displayRecords = DocumentTableController.displayRecords(from: records, groupByYearRead: true, currentYear: 2026)

    XCTAssertEqual(displayRecords.map(\.section), [.category(.currentlyReading)])
    XCTAssertEqual(displayRecords.map(\.noteIdentifier), ["paradise-lost"])
  }

  @MainActor func testPriorYearReadRecordIsKeptWhenBookIsCurrentlyReading() throws {
    let records = try [
      record("paradise-lost", section: .currentlyReading, startYear: 2026),
      record("paradise-lost", section: .read, finishYear: 1995, startYear: 1995),
    ]

    let displayRecords = DocumentTableController.displayRecords(from: records, groupByYearRead: true, currentYear: 2026)

    XCTAssertEqual(displayRecords.map(\.section), [.category(.currentlyReading), .readYear(1995)])
    XCTAssertEqual(displayRecords.map(\.noteIdentifier), ["paradise-lost", "paradise-lost"])
  }

  @MainActor func testReadYearSectionsAreOrderedAfterWantToRead() throws {
    let records = try [
      record("current", section: .currentlyReading, startYear: 2026),
      record("want", section: .wantToRead),
      record("read-2026", section: .read, finishYear: 2026, startYear: 2026),
      record("read-2025", section: .read, finishYear: 2025, startYear: 2025),
    ]
    let displayRecords = DocumentTableController.displayRecords(from: records, groupByYearRead: true, currentYear: 2026)

    let sections = DocumentTableController.orderedSections(for: displayRecords)

    XCTAssertEqual(sections, [.category(.currentlyReading), .category(.wantToRead), .readYear(2026), .readYear(2025)])
  }

  @MainActor func testUngroupedReadRecordsAreDeduplicatedByNoteIdentifier() throws {
    let records = try [
      record("paradise-lost", section: .read, finishYear: 2026, startYear: 2026),
      record("paradise-lost", section: .read, finishYear: 1995, startYear: 1995),
    ]

    let displayRecords = DocumentTableController.displayRecords(from: records, groupByYearRead: false, currentYear: 2026)

    XCTAssertEqual(displayRecords.map(\.section), [.category(.read)])
    XCTAssertEqual(displayRecords.map(\.noteIdentifier), ["paradise-lost"])
  }

  func testDefaultExpandedSectionsAreCurrentlyReadingAndCurrentReadYear() {
    XCTAssertTrue(BookCollectionViewSection.category(.currentlyReading).isExpandedByDefault(currentYear: 2026))
    XCTAssertTrue(BookCollectionViewSection.readYear(2026).isExpandedByDefault(currentYear: 2026))
  }

  func testDefaultCollapsedSectionsExcludePriorReadYearsAndOtherCategories() {
    XCTAssertFalse(BookCollectionViewSection.category(.wantToRead).isExpandedByDefault(currentYear: 2026))
    XCTAssertFalse(BookCollectionViewSection.category(.read).isExpandedByDefault(currentYear: 2026))
    XCTAssertFalse(BookCollectionViewSection.category(.other).isExpandedByDefault(currentYear: 2026))
    XCTAssertFalse(BookCollectionViewSection.readYear(2025).isExpandedByDefault(currentYear: 2026))
  }

  private func record(
    _ noteIdentifier: String,
    section: BookSection?,
    finishYear: Int? = nil,
    startYear: Int? = nil
  ) throws -> NoteIdentifierRecord {
    var dictionary: [String: Any] = [
      "noteIdentifier": noteIdentifier,
    ]
    if let section {
      dictionary["bookSection"] = section.rawValue
    }
    if let finishYear {
      dictionary["finishYear"] = finishYear
    }
    if let startYear {
      dictionary["startYear"] = startYear
    }
    let data = try JSONSerialization.data(withJSONObject: dictionary)
    return try JSONDecoder().decode(NoteIdentifierRecord.self, from: data)
  }
}
