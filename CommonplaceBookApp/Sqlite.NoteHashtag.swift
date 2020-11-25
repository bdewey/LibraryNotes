//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import GRDB

extension Sqlite {
  /// Core record for the `noteHashtag` association
  struct NoteHashtag: Codable, FetchableRecord, PersistableRecord {
    var noteId: FlakeID
    var hashtag: String

    enum Columns {
      static let noteId = Column(NoteHashtag.CodingKeys.noteId)
      static let hashtag = Column(NoteHashtag.CodingKeys.hashtag)
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
