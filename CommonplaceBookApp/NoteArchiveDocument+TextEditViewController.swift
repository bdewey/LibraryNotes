// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

extension NoteDocumentStorage {
  public func textEditViewController(
    _ viewController: TextEditViewController,
    didChange markdown: String
  ) {
    if let noteIdentifier = viewController.noteIdentifier {
      changeTextContents(for: noteIdentifier, to: markdown)
    } else {
      let now = Date()
      do {
        let noteIdentifier = try noteArchiveQueue.sync {
          try noteArchive.insertNote(markdown, contentChangeTime: now)
        }
        viewController.noteIdentifier = noteIdentifier
        invalidateSavedSnippets()
        notePropertiesDidChange.send()
      } catch {
        DDLogError("Unexpected error creating page: \(error)")
      }
    }
  }

  public func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    if hasUnsavedChanges {
      save(to: fileURL, for: .forOverwriting, completionHandler: nil)
    }
  }
}
