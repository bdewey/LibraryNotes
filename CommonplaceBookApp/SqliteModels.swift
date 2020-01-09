// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

// swiftlint:disable nesting

enum Sqlite {
  /// Core record for the `note` table
  struct Note: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var modifiedTimestamp: Date
    var hasText: Bool

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let title = Column(CodingKeys.title)
      static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    }

    static let noteHashtags = hasMany(NoteHashtag.self)
    static let hashtags = hasMany(Hashtag.self, through: noteHashtags, using: NoteHashtag.hashtag)

    var hashtags: QueryInterfaceRequest<Hashtag> {
      return request(for: Note.hashtags)
    }

    static let challengeTemplates = hasMany(ChallengeTemplate.self)
    var challengeTemplates: QueryInterfaceRequest<ChallengeTemplate> { request(for: Note.challengeTemplates) }

    static let noteText = belongsTo(NoteText.self)
  }

  /// Result structure from fetching a Note plus all of its hashtags
  struct NoteMetadata: Decodable, FetchableRecord {
    var id: String
    var title: String
    var modifiedTimestamp: Date
    var hasText: Bool
    var hashtags: [Hashtag]

    static let request = Note.including(all: Note.hashtags)
  }

  struct NoteText: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var text: String
    var noteId: String

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }
  }

  /// Core record for the `hashtag` table
  struct Hashtag: Codable, FetchableRecord, PersistableRecord {
    var id: String

    enum Columns {
      static let id = Column(CodingKeys.id)
    }
  }

  /// Core record for the `noteHashtag` association
  struct NoteHashtag: Codable, FetchableRecord, PersistableRecord {
    var noteId: String
    var hashtagId: String

    enum Columns {
      static let noteId = Column(CodingKeys.noteId)
      static let hashtagId = Column(CodingKeys.hashtagId)
    }

    static let note = belongsTo(Note.self)
    static let hashtag = belongsTo(Hashtag.self)
  }

  struct ChallengeTemplate: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var type: String
    var rawValue: String
    var noteId: String

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let type = Column(CodingKeys.type)
      static let rawValue = Column(CodingKeys.rawValue)
      static let noteId = Column(CodingKeys.noteId)
    }

    static let note = belongsTo(Note.self)
    static let challenges = hasMany(Challenge.self)

    var challenges: QueryInterfaceRequest<Challenge> { request(for: ChallengeTemplate.challenges) }
  }

  struct Challenge: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var index: Int
    var reviewCount: Int = 0
    var totalCorrect: Int = 0
    var totalIncorrect: Int = 0
    var lastReview: Date?
    var due: Date?
    var challengeTemplateId: String

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    enum Columns {
      static let index = Column(CodingKeys.index)
      static let challengeTemplateId = Column(CodingKeys.challengeTemplateId)
    }

    static let challengeTemplate = belongsTo(ChallengeTemplate.self)
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
}
