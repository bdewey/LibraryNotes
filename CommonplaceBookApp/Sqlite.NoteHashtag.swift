// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  /// Core record for the `noteHashtag` association
  struct NoteHashtag: Codable, FetchableRecord, PersistableRecord {
    var noteId: FlakeID
    var hashtagId: String

    enum Columns {
      static let noteId = Column(CodingKeys.noteId)
      static let hashtagId = Column(CodingKeys.hashtagId)
    }

    static let note = belongsTo(Note.self)
    static let hashtag = belongsTo(Hashtag.self)

    static func createV1Table(in database: Database) throws {
      try database.create(table: "noteHashtag", body: { table in
        table.column("noteId", .text)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
        table.column("hashtagId", .text)
          .notNull()
          .indexed()
          .references("hashtag", onDelete: .cascade)
        table.primaryKey(["noteId", "hashtagId"])
      })
    }

    static func createV2Table(in database: Database, named tableName: String = "noteHashtag") throws {
      try database.create(table: tableName, body: { table in
        table.column("noteId", .integer)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
        table.column("hashtagId", .text)
          .notNull()
          .indexed()
          .references("hashtag", onDelete: .cascade)
        table.primaryKey(["noteId", "hashtagId"])
      })
    }

    static func migrateTableFromV1ToV2(in database: Database) throws {
      try database.alter(table: "noteHashtag", body: { table in
        table.add(column: "noteFlakeId", .integer).notNull().defaults(to: 0)
      })
      let update = try database.makeUpdateStatement(
        sql: "UPDATE noteHashtag SET noteFlakeId = :flakeId WHERE rowId = :id"
      )
      try database.updateRows(selectSql: "SELECT rowId, noteId FROM noteHashtag", updateStatement: update) { row in
        let rowId: Int = row["rowId"]
        let noteId: String = row["noteId"]
        guard let flakeId = try Int.fetchOne(database, Note.select(sql: "createID").filter(key: noteId)) else {
          throw MigrationError.cannotFindNoteID(noteId)
        }
        return ["flakeId": flakeId, "id": rowId]
      }
      try database.rewriteTable(named: "noteHashtag", columns: "noteFlakeId, hashtagId") { tableName in
        try Self.createV2Table(in: database, named: tableName)
      }
    }
  }
}
