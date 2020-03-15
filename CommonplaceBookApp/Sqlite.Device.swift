// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct Device: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var uuid: String
    var name: String
    var updateSequenceNumber: Int64

    static func createV1Table(in database: Database) throws {
      try database.create(table: "device", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("uuid", .text).notNull().unique().indexed()
        table.column("name", .text).notNull()
        table.column("updateSequenceNumber", .integer).notNull()
      })
    }

    enum Columns {
      static let uuid = Column(CodingKeys.uuid)
    }

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }
  }
}
