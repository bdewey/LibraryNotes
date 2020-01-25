// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  /// Core record for the `note` table
  struct Note: Codable, FetchableRecord, PersistableRecord {
    var id: FlakeID
    var title: String
    var modifiedTimestamp: Date
    var modifiedDevice: Int64
    var hasText: Bool

    static func createV1Table(in database: Database) throws {
      try database.create(table: "note", body: { table in
        table.column("id", .text).primaryKey()
        table.column("title", .text).notNull().defaults(to: "")
        table.column("modifiedTimestamp", .datetime).notNull()
        table.column("hasText", .boolean).notNull()
      })
    }

    static func createV2Table(in database: Database, named name: String = "note") throws {
      try database.create(table: name, body: { table in
        table.column("id", .integer).primaryKey()
        table.column("title", .text).notNull().defaults(to: "")
        table.column("modifiedTimestamp", .datetime).notNull()
        table.column("modifiedDevice", .integer).indexed().references("device", onDelete: .setNull)
        table.column("hasText", .boolean).notNull()
      })
    }

    static func migrateTableFromV1ToV2(in database: Database, flakeMaker: FlakeMaker) throws {
      try database.alter(table: "note", body: { table in
        // This should be unique & indexed, but it can't start that way because we can't
        // assign the right values to it.
        table.add(column: "createID", .integer).notNull().defaults(to: 0)
        table.add(column: "modifiedDevice", .integer).defaults(to: flakeMaker.instanceNumber)
      })
      try assignFlakeIDToAllRecords(in: database, flakeMaker: flakeMaker)
      try NoteText.migrateTableFromV1ToV2(in: database, flakeMaker: flakeMaker)
      try NoteHashtag.migrateTableFromV1ToV2(in: database)
      try ChallengeTemplate.migrateTableFromV1ToV2(in: database, flakeMaker: flakeMaker)
      try database.rewriteTable(named: "note", columns: "createID, title, modifiedTimestamp, modifiedDevice, hasText", tableBuilder: { newName in
        try Self.createV2Table(in: database, named: newName)
      })
    }

    private static func assignFlakeIDToAllRecords(in database: Database, flakeMaker: FlakeMaker) throws {
      let ids = try String.fetchAll(database, sql: "SELECT id FROM note")
      let flakeUpdate = try database.makeUpdateStatement(sql: "UPDATE note SET createID = :createID WHERE id = :id")
      for id in ids {
        try flakeUpdate.execute(arguments: ["id": id, "createID": flakeMaker.nextValue().rawValue])
      }
    }

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let title = Column(CodingKeys.title)
      static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    }

    static let noteHashtags = hasMany(NoteHashtag.self)
    static let hashtags = hasMany(Hashtag.self, through: noteHashtags, using: NoteHashtag.hashtag)

    var hashtags: QueryInterfaceRequest<Hashtag> {
      return request(for: Note.hashtags)
    }

    static let challengeTemplates = hasMany(ChallengeTemplate.self)
    var challengeTemplates: QueryInterfaceRequest<ChallengeTemplate> { request(for: Note.challengeTemplates) }

    static let noteText = belongsTo(NoteText.self)

    static let challenges = hasMany(Challenge.self, through: challengeTemplates, using: ChallengeTemplate.challenges)
    var challenges: QueryInterfaceRequest<Challenge> { request(for: Note.challenges) }
  }
}
