// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct AssetRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "asset"
  var id: String
  var data: Data

  enum Columns {
    static let id = Column(AssetRecord.CodingKeys.id)
  }
}
