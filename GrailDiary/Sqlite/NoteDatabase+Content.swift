// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

public struct ContentFromNote: Decodable, FetchableRecord, Identifiable, Hashable {
  public var id: String { "\(noteId):\(key)" }
  public var noteId: String
  public var key: String
  public var text: String
  public var role: String
  var note: NoteRecord

  public static func == (lhs: ContentFromNote, rhs: ContentFromNote) -> Bool {
    return lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  var noteIdentifier: Note.Identifier { note.id }
}

extension NotebookStructureViewController.StructureIdentifier {
  var allQuoteIdentifiersQuery: QueryInterfaceRequest<ContentIdentifier> {
    // TODO: Turn this in to .joining rather than .including
    if case .hashtag(let hashtag) = self {
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .including(required: ContentRecord.note.including(required: NoteRecord.noteHashtags.filter(NoteLinkRecord.Columns.targetTitle.like("\(hashtag)/%") || NoteLinkRecord.Columns.targetTitle.like("\(hashtag)"))))
        .asRequest(of: ContentIdentifier.self)
    } else {
      let folderValue = predefinedFolder?.rawValue
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .including(required: ContentRecord.note.filter(NoteRecord.Columns.folder == folderValue))
        .asRequest(of: ContentIdentifier.self)
    }
  }
}
