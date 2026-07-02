// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
public struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable, Equatable, Sendable {
  public static var databaseTableName: String { "entry" }
  public var noteIdentifier: String
  public var bookSection: BookSection?
  public var finishYear: Int?
  public var startYear: Int?

  public enum SortOrder: String, CaseIterable, Sendable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"
    case rating = "Rating"
    case dateRead = "Date Read"
  }

  static func sqlLiteral(
    structureIdentifier: NotebookStructureIdentifier,
    sortOrder: SortOrder,
    groupByYearRead: Bool,
    searchTerm: String?
  ) -> SQL {
    sql(structureIdentifier: structureIdentifier, groupByYearRead: groupByYearRead)
      + searchCondition(searchTerm: searchTerm)
      + orderClause(sortOrder: sortOrder, groupByYearRead: groupByYearRead)
  }

  private static func sql(structureIdentifier: NotebookStructureIdentifier, groupByYearRead: Bool) -> SQL {
    let baseSQL: SQL
    switch structureIdentifier {
    case .read:
      baseSQL = """
      SELECT
        scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        json_extract(readingHistory.value, '$.finish.month') AS finishMonth,
        json_extract(readingHistory.value, '$.finish.day') AS finishDay,
        json_extract(entry.json, '$.authorLastFirst') AS authorLastFirst,
        coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title')) AS titleSort,
        json_extract(entry.json, '$.creationTimestamp') AS creationTimestamp,
        json_extract(entry.json, '$.modifiedTimestamp') AS modifiedTimestamp,
        json_extract(entry.json, '$.book.rating') AS rating,
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
      baseSQL = """
      SELECT
        scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        json_extract(readingHistory.value, '$.finish.month') AS finishMonth,
        json_extract(readingHistory.value, '$.finish.day') AS finishDay,
        json_extract(entry.json, '$.authorLastFirst') AS authorLastFirst,
        coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title')) AS titleSort,
        json_extract(entry.json, '$.creationTimestamp') AS creationTimestamp,
        json_extract(entry.json, '$.modifiedTimestamp') AS modifiedTimestamp,
        json_extract(entry.json, '$.book.rating') AS rating,
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
      baseSQL = """
      SELECT
        scope AS noteIdentifier,
        json_extract(readingHistory.value, '$.start.year') AS startYear,
        json_extract(readingHistory.value, '$.finish.year') AS finishYear,
        json_extract(readingHistory.value, '$.finish.month') AS finishMonth,
        json_extract(readingHistory.value, '$.finish.day') AS finishDay,
        json_extract(entry.json, '$.authorLastFirst') AS authorLastFirst,
        coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title')) AS titleSort,
        json_extract(entry.json, '$.creationTimestamp') AS creationTimestamp,
        json_extract(entry.json, '$.modifiedTimestamp') AS modifiedTimestamp,
        json_extract(entry.json, '$.book.rating') AS rating,
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

    guard groupByYearRead else {
      return "SELECT DISTINCT * FROM (" + baseSQL + ")"
    }

    let groupedSQL: SQL = """
      SELECT
        noteIdentifier,
        min(startYear) AS startYear,
        coalesce(finishYear, startYear) AS finishYear,
        bookSection,
        max(finishMonth) AS finishMonth,
        max(finishDay) AS finishDay,
        max(authorLastFirst) AS authorLastFirst,
        max(titleSort) AS titleSort,
        max(creationTimestamp) AS creationTimestamp,
        max(modifiedTimestamp) AS modifiedTimestamp,
        max(rating) AS rating
      FROM (
      """ + baseSQL + """
      )
      GROUP BY noteIdentifier, coalesce(finishYear, startYear), bookSection
      """
    return "SELECT * FROM (" + groupedSQL + ")"
  }

  private static func searchCondition(searchTerm: String?) -> SQL {
    guard let searchTerm else {
      return ""
    }
    return " WHERE noteIdentifier IN (SELECT scope FROM entry JOIN entryFullText ON entryFullText.rowId = entry.rowId AND entryFullText MATCH \(searchTerm))"
  }

  private static func orderClause(sortOrder: SortOrder, groupByYearRead: Bool) -> SQL {
    var sortClauses: [SQL] = ["bookSection"]
    if groupByYearRead {
      sortClauses.append("finishYear DESC")
    }
    switch sortOrder {
    case .author:
      sortClauses.append(contentsOf: [
        "authorLastFirst",
        "modifiedTimestamp DESC",
      ])
    case .title:
      sortClauses.append(contentsOf: [
        "titleSort",
        "modifiedTimestamp DESC",
      ])
    case .creationTimestamp:
      sortClauses.append(contentsOf: [
        "creationTimestamp DESC",
      ])
    case .modificationTimestap:
      sortClauses.append(contentsOf: [
        "modifiedTimestamp DESC",
      ])
    case .rating:
      sortClauses.append(contentsOf: [
        "rating DESC",
        "modifiedTimestamp DESC",
      ])
    case .dateRead:
      sortClauses.append(contentsOf: [
        "finishMonth DESC",
        "finishDay DESC",
        "creationTimestamp DESC",
      ])
    }
    return " ORDER BY " + sortClauses.joined(separator: ",")
  }
}
