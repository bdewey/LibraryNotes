// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public extension NoteStorage {
  /// Copies the contents of the receiver to another storage.
  func migrate(to destination: NoteStorage) throws {
    let metadata = allMetadata
    for identifier in metadata.keys {
      let note = try self.note(noteIdentifier: identifier)
      for template in note.challengeTemplates {
        template.templateIdentifier = nil
      }
      // TODO: This gives notes new UUIDs in the destination. Is that OK?
      _ = try destination.createNote(note)
    }
  }
}
