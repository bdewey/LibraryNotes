// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Core record for the `noteHashtag` association
struct NoteLinkRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "noteLink"
  var noteId: String
  var targetTitle: String

  enum Columns: String, ColumnExpression {
    case noteId
    case targetTitle
  }

  static let note = belongsTo(NoteRecord.self)
}
