// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct TagsRecord: FetchableRecord, Codable {
  var tags: [String]

  private static func query(jsonSelector: String, database: Database) throws -> (sql: String, arguments: StatementArguments) {
    let query: SQL = """
    SELECT
        KEY,
        json_extract(json, '$.folder') AS folder,
        json_extract(json, \(jsonSelector)) AS tags
    FROM
        entry
    WHERE
        KEY = '.metadata'
        AND (
            folder IS NULL
            OR folder != 'recentlyDeleted'
        )
        AND tags IS NOT NULL
        AND json_array_length(tags) > 0
    """
    return try query.build(database)
  }

  static func fetchAll(_ database: Database, jsonSelector: String) throws -> [TagsRecord] {
    let (sql, arguments) = try query(jsonSelector: jsonSelector, database: database)
    return try TagsRecord.fetchAll(database, sql: sql, arguments: arguments)
  }

  static func tags(in database: Database, jsonSelector: String) throws -> Set<String> {
    var results: Set<String> = []
    let rows = try fetchAll(database, jsonSelector: jsonSelector)
    for row in rows {
      for tag in row.tags {
        results.insert(tag)
      }
    }
    return results
  }

  static func allTags(in database: Database) throws -> Set<String> {
    var bookTags = try tags(in: database, jsonSelector: "$.book.tags")
    let metadataTags = try tags(in: database, jsonSelector: "$.tags")
    bookTags.formUnion(metadataTags)
    return bookTags
  }
}
