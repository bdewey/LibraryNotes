// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

extension NoteArchiveDocument: TextEditViewControllerDelegate {
  func textEditViewController(
    _ viewController: TextEditViewController,
    didChange markdown: String
  ) {
    if let pageIdentifier = viewController.pageIdentifier {
      changeTextContents(for: pageIdentifier, to: markdown)
    } else {
      let now = Date()
      do {
        let pageIdentifier = try noteArchiveQueue.sync {
          try noteArchive.insertNote(markdown, contentChangeTime: now, versionTimestamp: now)
        }
        viewController.pageIdentifier = pageIdentifier
        invalidateSavedSnippets()
        notifyObservers(of: pageProperties)
      } catch {
        DDLogError("Unexpected error creating page: \(error)")
      }
    }
  }

  func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    if hasUnsavedChanges {
      save(to: fileURL, for: .forOverwriting, completionHandler: nil)
    }
  }
}
