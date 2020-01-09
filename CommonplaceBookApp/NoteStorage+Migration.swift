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

    for assetKey in assetKeys {
      if let data = try self.data(for: assetKey) {
        // TODO: We don't get to set the key for the asset? That will break image rendering.
        // TODO: Oh no, how do I get the type hint?
        _ = try destination.storeAssetData(data, key: assetKey)
      }
    }
  }
}
