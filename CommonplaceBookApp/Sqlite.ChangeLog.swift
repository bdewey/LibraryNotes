// Copyright © 2017-present Brian's Brain. All rights reserved.

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
