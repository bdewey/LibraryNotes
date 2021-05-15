//  Copyright © 2021 Brian's Brain. All rights reserved.

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
}

extension NotebookStructureViewController.StructureIdentifier {
  public var attributedQuotesQuery: QueryInterfaceRequest<ContentFromNote> {
    if case .hashtag(let hashtag) = self {
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .including(required: ContentRecord.note.including(required: NoteRecord.noteHashtags.filter(NoteLinkRecord.Columns.targetTitle.like("\(hashtag)/%") || NoteLinkRecord.Columns.targetTitle.like("\(hashtag)"))))
        .asRequest(of: ContentFromNote.self)
    } else {
      let folderValue = predefinedFolder?.rawValue
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .including(required: ContentRecord.note.filter(NoteRecord.Columns.folder == folderValue))
        .asRequest(of: ContentFromNote.self)
    }
  }
}

extension NoteDatabase {
  /// Returns the quotes from a given part of the notebook.
  func attributedQuotes(focusedOn structureIdentifier: NotebookStructureViewController.StructureIdentifier) throws -> [ContentFromNote] {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }

    return try dbQueue.read { db in
      try structureIdentifier.attributedQuotesQuery.asRequest(of: ContentFromNote.self).fetchAll(db)
    }
  }
}
