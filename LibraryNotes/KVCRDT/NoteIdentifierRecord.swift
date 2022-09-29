// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
public struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable, Equatable {
  public static var databaseTableName: String { "entry" }
  public var noteIdentifier: String
  public var bookSection: BookSection?
  public var finishYear: Int?
  public var startYear: Int?

  public enum SortOrder: String, CaseIterable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"
    case rating = "Rating"
    case dateRead = "Date Read"
  }

  static func sqlLiteral(
    structureIdentifier: NotebookStructureViewController.StructureIdentifier,
    sortOrder: SortOrder,
    groupByYearRead: Bool,
    searchTerm: String?
  ) -> SQL {
    sql(structureIdentifier: structureIdentifier)
      + searchCondition(searchTerm: searchTerm)
      + orderClause(sortOrder: sortOrder, groupByYearRead: groupByYearRead)
  }

  private static func sql(structureIdentifier: NotebookStructureViewController.StructureIdentifier) -> SQL {
    switch structureIdentifier {
    case .read:
      return """
      SELECT
        DISTINCT scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        CASE
            WHEN json_extract(readingHistory.value, '$.start.year') IS NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'wantToRead'
            WHEN json_extract(readingHistory.value, '$.start.year') IS NOT NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'currentlyReading'
            WHEN json_extract(readingHistory.value, '$.finish.year') IS NOT NULL THEN 'read'
        END as bookSection
      FROM
        entry
        LEFT JOIN json_each(entry.json, '$.book.readingHistory.entries') AS readingHistory
      WHERE
        entry.KEY = '.metadata'
        AND json_valid(entry.json)
        AND (
            json_extract(entry.json, '$.folder') IS NULL
            OR json_extract(entry.json, '$.folder') != 'recentlyDeleted'
        )
      """

    case .trash:
      return """
      SELECT
        DISTINCT scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        CASE
            WHEN json_extract(readingHistory.value, '$.start.year') IS NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'wantToRead'
            WHEN json_extract(readingHistory.value, '$.start.year') IS NOT NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'currentlyReading'
            WHEN json_extract(readingHistory.value, '$.finish.year') IS NOT NULL THEN 'read'
        END as bookSection
      FROM
        entry
        LEFT JOIN json_each(entry.json, '$.book.readingHistory.entries') AS readingHistory
      WHERE
        entry.KEY = '.metadata'
        AND json_valid(entry.json)
        AND json_extract(entry.json, '$.folder') == 'recentlyDeleted'
      """

    case .hashtag(let hashtag):
      return """
      SELECT
        DISTINCT scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        CASE
            WHEN json_extract(readingHistory.value, '$.start.year') IS NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'wantToRead'
            WHEN json_extract(readingHistory.value, '$.start.year') IS NOT NULL AND json_extract(readingHistory.value, '$.finish.year') IS NULL THEN 'currentlyReading'
            WHEN json_extract(readingHistory.value, '$.finish.year') IS NOT NULL THEN 'read'
        END as bookSection
      FROM
        entry
        LEFT JOIN json_each(entry.json, '$.book.tags') AS bookTags
        LEFT JOIN json_each(entry.json, '$.tags') AS metadataTags
        LEFT JOIN json_each(entry.json, '$.book.readingHistory.entries') AS readingHistory
      WHERE
        entry.KEY = '.metadata'
        AND json_valid(entry.json)
        AND (
            bookTags.value = \(hashtag)
            OR metadataTags.value = \(hashtag)
        )
      """
    }
  }

  private static func searchCondition(searchTerm: String?) -> SQL {
    guard let searchTerm else {
      return ""
    }
    return "AND entry.scope IN (SELECT scope FROM entry JOIN entryFullText ON entryFullText.rowId = entry.rowId AND entryFullText MATCH \(searchTerm))"
  }

  private static func orderClause(sortOrder: SortOrder, groupByYearRead: Bool) -> SQL {
    var sortClauses: [SQL] = ["bookSection"]
    if groupByYearRead {
      sortClauses.append("finishYear DESC")
    }
    switch sortOrder {
    case .author:
      sortClauses.append(contentsOf: [
        "json_extract(entry.json, '$.authorLastFirst')",
        "json_extract(entry.json, '$.modifiedTimestamp') DESC",
      ])
    case .title:
      sortClauses.append(contentsOf: [
        "coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title'))",
        "json_extract(entry.json, '$.modifiedTimestamp') DESC",
      ])
    case .creationTimestamp:
      sortClauses.append(contentsOf: [
        "json_extract(entry.json, '$.creationTimestamp') DESC",
      ])
    case .modificationTimestap:
      sortClauses.append(contentsOf: [
        "json_extract(entry.json, '$.modifiedTimestamp') DESC",
      ])
    case .rating:
      sortClauses.append(contentsOf: [
        "json_extract(entry.json, '$.book.rating') DESC",
        "json_extract(entry.json, '$.modifiedTimestamp') DESC",
      ])
    case .dateRead:
      sortClauses.append(contentsOf: [
        "json_extract(readingHistory.value, '$.finish.month') DESC",
        "json_extract(readingHistory.value, '$.finish.day') DESC",
        "json_extract(entry.json, '$.creationTimestamp') DESC",
      ])
    }
    return "ORDER BY " + sortClauses.joined(separator: ",")
  }
}
