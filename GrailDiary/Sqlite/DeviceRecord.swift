// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct DeviceRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "device"
  var uuid: String
  var name: String
  var updateSequenceNumber: Int64

  enum Columns {
    static let uuid = Column(DeviceRecord.CodingKeys.uuid)
  }
}
