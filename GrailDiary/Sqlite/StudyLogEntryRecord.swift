// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct StudyLogEntryRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "promptHistory"
  var id: Int64?
  var timestamp: Date
  var correct: Int
  var incorrect: Int
  var noteId: String
  var promptKey: String
  var promptIndex: Int

  enum Columns {
    static let timestamp = Column(StudyLogEntryRecord.CodingKeys.timestamp)
  }

  static let prompt = belongsTo(PromptRecord.self)
}
