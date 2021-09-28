// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable {
  static var databaseTableName: String { "entry" }
  var scope: String

  static func sqlLiteral(
    structureIdentifier: NotebookStructureViewController.StructureIdentifier,
    sortOrder: BookCollectionViewSnapshotBuilder.SortOrder
  ) -> SQL {
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
    ORDER BY
        json_extract(entry.json, '$.modifiedTimestamp') DESC;
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
    ORDER BY
        json_extract(entry.json, '$.modifiedTimestamp') DESC;
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
    ORDER BY
        json_extract(entry.json, '$.modifiedTimestamp') DESC;
    """
    }
  }
}
