// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  /// For rows that contain text, this is the text.
  struct NoteText: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var text: String
    var noteId: FlakeID

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    static func createV1Table(in database: Database) throws {
      try database.create(table: "noteText", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("text", .text).notNull()
        table.column("noteId", .text).notNull().indexed().unique().references("note", onDelete: .cascade)
      })
    }

    static func createV2Table(in database: Database, named name: String = "noteText") throws {
      try database.create(table: name, body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("text", .text).notNull()
        table.column("noteId", .integer).notNull().indexed().unique().references("note", onDelete: .cascade)
      })
    }

    static func migrateTableFromV1ToV2(in database: Database, flakeMaker: FlakeMaker) throws {
      try database.alter(table: "noteText", body: { table in
        table.add(column: "noteFlakeId", .integer).notNull().defaults(to: 0)
      })
      let idUpdate = try database.makeUpdateStatement(sql: "UPDATE noteText SET noteFlakeId = :flakeId WHERE id = :id")
      try database.updateRows(selectSql: "SELECT id, noteId FROM noteText", updateStatement: idUpdate) { row -> StatementArguments in
        let id: Int = row["id"]
        let noteId: String = row["noteId"]
        // TODO: Vulnerable to Sql injection but the `arguments:` version isn't compiling for some reason
        guard let flakeID = try Int.fetchOne(database, sql: "SELECT createID FROM note WHERE id = '\(noteId)'") else {
          throw MigrationError.cannotFindNoteID(noteId)
        }
        return ["flakeId": flakeID, "id": id]
      }
      try database.rewriteTable(named: "noteText", columns: "id, text, noteFlakeId", tableBuilder: { tableName in
        try Self.createV2Table(in: database, named: tableName)
      })
    }
  }
}
