// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
public struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable, Equatable {
  public static var databaseTableName: String { "entry" }
  public var noteIdentifier: String
  public var bookSection: BookSection?

  public enum SortOrder: String, CaseIterable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"
    case rating = "Rating"
  }

  static func sqlLiteral(
    structureIdentifier: NotebookStructureViewController.StructureIdentifier,
    sortOrder: SortOrder,
    searchTerm: String?
  ) -> SQL {
    return sql(structureIdentifier: structureIdentifier)
      + searchCondition(searchTerm: searchTerm)
      + orderClause(sortOrder: sortOrder)
  }

  private static func sql(structureIdentifier: NotebookStructureViewController.StructureIdentifier) -> SQL {
    switch structureIdentifier {
    case .read:
      return """
        SELECT
            DISTINCT scope AS noteIdentifier,
            json_extract(entry.json, '$.bookSection') AS bookSection
        FROM
            entry
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
          json_extract(entry.json, '$.bookSection') AS bookSection
      FROM
          entry
      WHERE
          entry.KEY = '.metadata'
          AND json_valid(entry.json)
          AND json_extract(entry.json, '$.folder') == 'recentlyDeleted'
      """

    case .hashtag(let hashtag):
      return """
      SELECT
          DISTINCT scope AS noteIdentifier,
          json_extract(entry.json, '$.bookSection') AS bookSection,
          metadataTags.value,
          bookTags.value
      FROM
          entry
          LEFT JOIN json_each(entry.json, '$.book.tags') AS bookTags
          LEFT JOIN json_each(entry.json, '$.tags') AS metadataTags
      WHERE
          entry.KEY = '.metadata'
          AND json_valid(entry.json)
          AND (
              json_extract(entry.json, '$.folder') IS NULL
              OR json_extract(entry.json, '$.folder') != 'recentlyDeleted'
          )
          AND (
              bookTags.value = \(hashtag)
              OR metadataTags.value = \(hashtag)
          )
      """
    }
  }

  private static func searchCondition(searchTerm: String?) -> SQL {
    guard let searchTerm = searchTerm else {
      return ""
    }
    return "AND entry.scope IN (SELECT scope FROM entry JOIN entryFullText ON entryFullText.rowId = entry.rowId AND entryFullText MATCH \(searchTerm))"
  }

  private static func orderClause(sortOrder: SortOrder) -> SQL {
    switch sortOrder {
    case .author:
      return "ORDER BY bookSection, json_extract(entry.json, '$.authorLastFirst'), json_extract(entry.json, '$.modifiedTimestamp') DESC"
    case .title:
      return "ORDER BY bookSection, coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title')), json_extract(entry.json, '$.modifiedTimestamp') DESC"
    case .creationTimestamp:
      return "ORDER BY bookSection, json_extract(entry.json, '$.creationTimestamp') DESC"
    case .modificationTimestap:
      return "ORDER BY bookSection, json_extract(entry.json, '$.modifiedTimestamp') DESC"
    case .rating:
      return "ORDER BY bookSection, json_extract(entry.json, '$.book.rating') DESC, json_extract(entry.json, '$.modifiedTimestamp') DESC"
    }
  }
}

public extension Array where Element == NoteIdentifierRecord {
  /// Given an array of `NoteIdentifierRecord` structs that is sorted by `bookSection`, returns the partion boundaries for each `bookSection` value.
  var bookSectionPartitions: [BookSection: Range<Int>] {
    var results: [BookSection: Range<Int>] = [:]
    for (index, element) in enumerated() {
      let section = element.bookSection ?? .other
      if let existingRange = results[section] {
        results[section] = existingRange.lowerBound ..< index + 1
      } else {
        results[section] = index ..< index + 1
      }
    }
    return results
  }
}
