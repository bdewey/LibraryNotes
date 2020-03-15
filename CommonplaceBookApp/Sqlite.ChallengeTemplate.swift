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
        table.column("id", .integer).primaryKey()
        table.column("type", .text).notNull()
        table.column("rawValue", .text).notNull()
        table.column("noteId", .integer)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
      })
    }
  }
}
