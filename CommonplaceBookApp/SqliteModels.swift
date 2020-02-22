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
    var noteHashtags: [NoteHashtag]

    static let request = Note.including(all: Note.noteHashtags)
  }

  struct StudyLogEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var timestamp: Date
    var correct: Int
    var incorrect: Int
    var challengeId: Int64

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    enum Columns {
      static let timestamp = Column(CodingKeys.timestamp)
    }

    static let challenge = belongsTo(Challenge.self)
  }

  /// Includes all of the information needed to convert a Sqlite.StudyLogEntry to an in-memory StudyLog.entry.
  struct StudyLogEntryInfo: Codable, FetchableRecord {
    var studyLogEntry: StudyLogEntry
    var challenge: Challenge
  }

  struct Asset: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var data: Data

    enum Columns {
      static let id = Column(CodingKeys.id)
    }
  }

  struct Device: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var uuid: String
    var name: String

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }
  }
}
