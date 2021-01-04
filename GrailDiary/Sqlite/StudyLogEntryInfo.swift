// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Result structure from fetching a Note plus all of its hashtags
/// Includes all of the information needed to convert a Sqlite.StudyLogEntry to an in-memory StudyLog.entry.
struct StudyLogEntryInfo: Codable, FetchableRecord {
  var promptHistory: StudyLogEntryRecord
  var prompt: PromptRecord
}
