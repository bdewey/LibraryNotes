// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct Asset: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var data: Data

    static func createV1Table(in database: Database) throws {
      try database.create(table: "asset", body: { table in
        table.column("id", .text).primaryKey()
        table.column("data", .blob).notNull()
      })
    }

    enum Columns {
      static let id = Column(Asset.CodingKeys.id)
    }
  }
}
