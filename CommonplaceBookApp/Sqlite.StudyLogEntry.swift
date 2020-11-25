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
  struct StudyLogEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var timestamp: Date
    var correct: Int
    var incorrect: Int
    var challengeId: Int64

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    static func createV1Table(in database: Database) throws {
      try database.create(table: "studyLogEntry", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("timestamp", .datetime).notNull()
        table.column("correct", .integer).notNull().defaults(to: 0)
        table.column("incorrect", .integer).notNull().defaults(to: 0)
        table.column("challengeId", .integer)
          .notNull()
          .references("challenge", onDelete: .cascade)
      })
    }

    enum Columns {
      static let timestamp = Column(StudyLogEntry.CodingKeys.timestamp)
    }

    static let challenge = belongsTo(Challenge.self)
  }
}
