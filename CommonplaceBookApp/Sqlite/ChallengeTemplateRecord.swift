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

struct ChallengeTemplateRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "challengeTemplate"
  var id: String
  var type: String
  var rawValue: String
  var noteId: Note.Identifier

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let type = Column(CodingKeys.type)
    static let rawValue = Column(CodingKeys.rawValue)
    static let noteId = Column(CodingKeys.noteId)
  }

  /// The note that the challenge template is associated with
  static let note = belongsTo(NoteRecord.self)

  /// A query that will return the note associated with this template.
  var note: QueryInterfaceRequest<NoteRecord> {
    request(for: Self.note)
  }

  static let challenges = hasMany(ChallengeRecord.self)

  var challenges: QueryInterfaceRequest<ChallengeRecord> { request(for: ChallengeTemplateRecord.challenges) }

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
