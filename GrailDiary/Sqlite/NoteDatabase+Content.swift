// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

extension NotebookStructureViewController.StructureIdentifier {
  var allQuoteIdentifiersQuery: QueryInterfaceRequest<ContentIdentifier> {
    // TODO: Turn this in to .joining rather than .including
    if case .hashtag(let hashtag) = self {
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .joining(required: ContentRecord.note.including(required: NoteRecord.noteHashtags.filter(NoteLinkRecord.Columns.targetTitle.like("\(hashtag)/%") || NoteLinkRecord.Columns.targetTitle.like("\(hashtag)"))))
        .asRequest(of: ContentIdentifier.self)
    } else {
      let folderValue = predefinedFolder?.rawValue
      return ContentRecord
        .filter(ContentRecord.Columns.role == "prompt=quote")
        .joining(required: ContentRecord.note.filter(NoteRecord.Columns.folder == folderValue))
        .asRequest(of: ContentIdentifier.self)
    }
  }
}
