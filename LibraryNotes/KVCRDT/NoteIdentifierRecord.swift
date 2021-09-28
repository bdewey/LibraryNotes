// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable {
  static var databaseTableName: String { "entry" }
  var scope: String

  static func sqlLiteral(
    structureIdentifier: NotebookStructureViewController.StructureIdentifier,
    sortOrder: BookCollectionViewSnapshotBuilder.SortOrder,
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
        DISTINCT scope
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
        DISTINCT scope
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
        scope,
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

  private static func orderClause(sortOrder: BookCollectionViewSnapshotBuilder.SortOrder) -> SQL {
    switch sortOrder {
    case .author:
      return "ORDER BY name_sort(json_extract(entry.json, '$.book.authors[0]'))"
    case .title:
      return "ORDER BY coalesce(json_extract(entry.json, '$.book.title'), json_extract(entry.json, '$.title')), json_extract(entry.json, '$.modifiedTimestamp') DESC"
    case .creationTimestamp:
      return "ORDER BY json_extract(entry.json, '$.creationTimestamp') DESC"
    case .modificationTimestap:
      return "ORDER BY json_extract(entry.json, '$.modifiedTimestamp') DESC"
    case .rating:
      return "ORDER BY json_extract(entry.json, '$.book.rating') DESC, json_extract(entry.json, '$.modifiedTimestamp') DESC"
    }
  }
}
