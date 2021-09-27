// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation
import GRDB

/// Used to filter & sort note identifiers from the database.
struct NoteIdentifierRecord: TableRecord, FetchableRecord, Codable {
  static var databaseTableName: String { "entry" }
  var scope: String
}
