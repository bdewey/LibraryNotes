// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// For rows that contain text, this is the text.
struct BinaryContentRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "binaryContent"
  var blob: Data
  var noteId: String
  var key: String
  var role: ContentRole
  var mimeType: String

  enum Columns: String, ColumnExpression {
    case blob
    case noteId
    case key
    case role
    case mimeType
  }

  static var note = belongsTo(NoteRecord.self)
}
