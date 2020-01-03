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
    var contents: String?

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let title = Column(CodingKeys.title)
      static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
      static let contents = Column(CodingKeys.contents)
    }

    static let noteHashtags = hasMany(NoteHashtag.self)
    static let hashtags = hasMany(Hashtag.self, through: noteHashtags, using: NoteHashtag.hashtag)

    var hashtags: QueryInterfaceRequest<Hashtag> {
      return request(for: Note.hashtags)
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
    var id: Int64?
    var text: String
    var rawValue: String
    var noteId: String

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    enum Columns {
      static let id = Column(CodingKeys.id)
      static let text = Column(CodingKeys.text)
      static let rawValue = Column(CodingKeys.rawValue)
      static let noteId = Column(CodingKeys.noteId)
    }
  }

  struct Challenge: Codable, FetchableRecord, PersistableRecord {
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

  struct StudyLogEntry: Codable, FetchableRecord, PersistableRecord {
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
