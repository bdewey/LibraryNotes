// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

// swiftlint:disable nesting

enum Sqlite {
  enum MigrationError: Error {
    case cannotFindNoteID(String)
    case cannotFindTemplateID(String)
  }

  /// Result structure from fetching a Note plus all of its hashtags
  struct NoteMetadata: Decodable, FetchableRecord {
    var id: Int64
    var title: String
    var modifiedTimestamp: Date
    var hasText: Bool
    var deleted: Bool
    var noteHashtags: [NoteHashtag]

    static let request = Note.including(all: Note.noteHashtags)
  }

  /// Includes all of the information needed to convert a Sqlite.StudyLogEntry to an in-memory StudyLog.entry.
  struct StudyLogEntryInfo: Codable, FetchableRecord {
    var studyLogEntry: StudyLogEntry
    var challenge: Challenge
  }

}
