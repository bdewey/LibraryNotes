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
    var noteTextId: Int64?

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
    var noteTextId: Int64?
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
  }

  struct Challenge: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var index: Int
    var reviewCount: Int
    var totalCorrect: Int
    var totalIncorrect: Int
    var due: Date
    var challengeTemplateId: Int64

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }
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
  }
}
