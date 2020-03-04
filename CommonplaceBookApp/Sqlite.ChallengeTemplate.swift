// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct ChallengeTemplate: Codable, FetchableRecord, PersistableRecord {
    var id: FlakeID
    var type: String
    var rawValue: String
    var noteId: FlakeID

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let type = Column(CodingKeys.type)
      static let rawValue = Column(CodingKeys.rawValue)
      static let noteId = Column(CodingKeys.noteId)
    }

    /// The note that the challenge template is associated with
    static let note = belongsTo(Note.self)

    /// A query that will return the note associated with this template.
    var note: QueryInterfaceRequest<Note> {
      request(for: Self.note)
    }

    static let challenges = hasMany(Challenge.self)

    var challenges: QueryInterfaceRequest<Challenge> { request(for: ChallengeTemplate.challenges) }

    static func createV1Table(in database: Database) throws {
      try database.create(table: "challengeTemplate", body: { table in
        table.column("id", .text).primaryKey()
        table.column("type", .text).notNull()
        table.column("rawValue", .text).notNull()
        table.column("noteId", .text)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
      })
    }

    static func createV2Table(in database: Database, named tableName: String = "challengeTemplate") throws {
      try database.create(table: tableName, body: { table in
        table.column("id", .integer).primaryKey()
        table.column("type", .text).notNull()
        table.column("rawValue", .text).notNull()
        table.column("noteId", .integer)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
      })
    }

    static func migrateTableFromV1ToV2(in database: Database, flakeMaker: FlakeMaker) throws {
      try database.alter(table: "challengeTemplate", body: { table in
        table.add(column: "templateFlakeId", .integer).notNull().defaults(to: 0)
        table.add(column: "noteFlakeId", .integer).notNull().defaults(to: 0)
      })
      let update = try database.makeUpdateStatement(
        sql: "UPDATE challengeTemplate SET templateFlakeId = :templateFlakeId, noteFlakeId = :flakeId WHERE id = :id"
      )
      try database.updateRows(selectSql: "SELECT id, noteId FROM challengeTemplate", updateStatement: update) { row in
        let id: String = row["id"]
        let noteId: String = row["noteId"]
        let templateFlakeId = flakeMaker.nextValue()
        guard let flakeId = try Int.fetchOne(database, Note.select(sql: "createID").filter(key: noteId)) else {
          throw MigrationError.cannotFindNoteID(noteId)
        }
        return ["templateFlakeId": templateFlakeId.rawValue, "flakeId": flakeId, "id": id]
      }
      try Challenge.migrateTableFromV1ToV2(in: database)
      try database.rewriteTable(named: "challengeTemplate", columns: "templateFlakeId, type, rawValue, noteFlakeId") { tableName in
        try Self.createV2Table(in: database, named: tableName)
      }
    }
  }
}
