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

/// For rows that contain text, this is the text.
struct NoteTextRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "noteText"
  var id: Int64?
  var text: String
  var noteId: String

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