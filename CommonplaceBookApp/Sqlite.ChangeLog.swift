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
  struct ChangeLog: Codable, FetchableRecord, PersistableRecord {
    var deviceID: Int64
    var updateSequenceNumber: Int64
    var timestamp: Date
    var changeDescription: String

    static func createV1Table(in database: Database) throws {
      try database.create(table: "changeLog", body: { table in
        table.column("deviceID", .integer).notNull().indexed().references("device", onDelete: .cascade)
        table.column("updateSequenceNumber", .integer).notNull()
        table.column("timestamp", .datetime).notNull()
        table.column("changeDescription", .text).notNull()

        table.primaryKey(["deviceID", "updateSequenceNumber"])
      })
    }
  }
}
