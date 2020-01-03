// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

enum Sqlite {
  /// Core record for the `note` table
  struct Note: Codable {
    var id: String
    var title: String
    var modifiedTimestamp: Date
    var contents: String?
  }

  /// Core record for the `hashtag` table
  struct Hashtag: Codable {
    var id: String
  }

  /// Core record for the `noteHashtag` association
  struct NoteHashtag: Codable {
    var id: Int64?
    var noteId: String
    var hashtagId: String
  }
}

extension Sqlite.Note: FetchableRecord, PersistableRecord {
  enum Columns {
    static let id = Column(CodingKeys.id)
    static let title = Column(CodingKeys.title)
    static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    static let contents = Column(CodingKeys.contents)
  }
}

extension Sqlite.Hashtag: FetchableRecord, PersistableRecord {
  enum Columns {
    static let id = Column(CodingKeys.id)
  }
}

extension Sqlite.NoteHashtag: FetchableRecord, PersistableRecord {
  enum Columns {
    static let id = Column(CodingKeys.id)
    static let noteId = Column(CodingKeys.noteId)
    static let hashtagId = Column(CodingKeys.hashtagId)
  }

  mutating func didInsert(with rowID: Int64, for column: String?) {
    id = rowID
  }
}
