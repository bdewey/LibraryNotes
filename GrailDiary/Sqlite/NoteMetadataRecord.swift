// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct NoteMetadataRecord: Decodable, FetchableRecord {
  var id: Note.Identifier
  var title: String
  var creationTimestamp: Date
  var modifiedTimestamp: Date
  var deleted: Bool
  var noteLinks: [NoteLinkRecord]

  static let request = NoteRecord.including(all: NoteRecord.noteHashtags)
}
