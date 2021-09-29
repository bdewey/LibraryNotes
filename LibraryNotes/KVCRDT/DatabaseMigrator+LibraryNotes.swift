// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation
import GRDB

internal extension DatabaseMigrator {
  static let libraryNotes: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    return migrator
  }()
}
