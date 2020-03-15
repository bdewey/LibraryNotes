// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  /// Core record for the `noteHashtag` association
  struct NoteHashtag: Codable, FetchableRecord, PersistableRecord {
    var noteId: FlakeID
    var hashtag: String

    enum Columns {
      static let noteId = Column(CodingKeys.noteId)
      static let hashtag = Column(CodingKeys.hashtag)
    }

    static let note = belongsTo(Note.self)

    static func createV1Table(in database: Database) throws {
      try database.create(table: "noteHashtag", body: { table in
        table.column("noteId", .integer)
          .notNull()
          .indexed()
          .references("note", onDelete: .cascade)
        table.column("hashtag", .text)
          .notNull()
          .indexed()
        table.primaryKey(["noteId", "hashtag"])
      })
    }
  }
}
