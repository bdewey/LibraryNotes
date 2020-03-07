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
      })
    }

    static func createV2Table(in database: Database, named name: String) throws {
      try database.create(table: name, body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("uuid", .text).notNull().unique().indexed()
        table.column("name", .text).notNull()
        table.column("updateSequenceNumber", .integer).notNull()
      })
    }

    static func migrateTableFromV1ToV2(in database: Database) throws {
      try database.alter(table: "device", body: { table in
        table.add(column: "updateSequenceNumber", .integer).notNull().defaults(to: 0)
      })
      try database.rewriteTable(named: "device", columns: "id, uuid, name, updateSequenceNumber", tableBuilder: { tableName in
        try Self.createV2Table(in: database, named: tableName)
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
