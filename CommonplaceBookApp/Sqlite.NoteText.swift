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
        table.column("noteId", .integer).notNull().indexed().unique().references("note", onDelete: .cascade)
      })
    }
  }
}
