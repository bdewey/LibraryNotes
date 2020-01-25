// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct Challenge: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var index: Int
    var reviewCount: Int = 0
    var lapseCount: Int = 0
    var totalCorrect: Int = 0
    var totalIncorrect: Int = 0
    var lastReview: Date?
    var idealInterval: Double?
    var due: Date?
    var challengeTemplateId: Int64
    var spacedRepetitionFactor: Double = 2.5

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    enum Columns {
      static let index = Column(CodingKeys.index)
      static let challengeTemplateId = Column(CodingKeys.challengeTemplateId)
      static let due = Column(CodingKeys.due)
    }

    static let challengeTemplate = belongsTo(ChallengeTemplate.self)

    static func createV1Table(in database: Database) throws {
      try database.create(table: "challenge", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("challengeTemplateId", .text)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
      })
    }

    static func createV2Table(in database: Database, named tableName: String) throws {
      try database.create(table: tableName, body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("spacedRepetitionFactor", .double).notNull().defaults(to: 2.5)
        table.column("lapseCount", .double).notNull().defaults(to: 0)
        table.column("idealInterval", .double)
        table.column("challengeTemplateId", .integer)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
      })
    }

    static func migrateTableFromV1ToV2(in database: Database) throws {
      try database.alter(table: "challenge", body: { table in
        table.add(column: "challengeTemplateFlakeID", .integer).notNull().defaults(to: 0)
      })
      let update = try database.makeUpdateStatement(
        sql: "UPDATE challenge SET challengeTemplateFlakeID = :flakeID WHERE id = :id"
      )
      try database.updateRows(selectSql: "SELECT id, challengeTemplateId FROM challenge", updateStatement: update) { row in
        let id: Int64 = row["id"]
        let challengeTemplateID: String = row["challengeTemplateId"]
        guard let flakeId = try Int.fetchOne(database, ChallengeTemplate.select(sql: "templateFlakeId").filter(key: challengeTemplateID)) else {
          throw MigrationError.cannotFindTemplateID(challengeTemplateID)
        }
        return ["flakeID": flakeId, "id": id]
      }
      try database.rewriteTable(named: "challenge", columns: "id, `index`, reviewCount, totalCorrect, totalIncorrect, lastReview, due, spacedRepetitionFactor, lapseCount, idealInterval, challengeTemplateFlakeID", tableBuilder: { tableName in
        try Self.createV2Table(in: database, named: tableName)
      })
    }
  }
}
