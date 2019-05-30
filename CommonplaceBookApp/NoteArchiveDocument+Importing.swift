// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import UIKit

/// Importing existing files into the archive.
public extension NoteArchiveDocument {
  /// Asynchronously imports the contents of a file into the archive.
  ///
  /// - note: If this file has already been imported (determined by the same change date
  ///         or content hash), then there is no actual change to the archive.
  ///
  /// - parameter fileName: Name of the file we are importing.
  /// - parameter text: The file's plain text contents
  /// - parameter contentChangeDate: The time the file was modified.
  /// - parameter importDate: The time we are doing the import.
  func importFile(
    named fileName: String,
    text: String,
    contentChangeDate: Date,
    importDate: Date,
    completion: (() -> Void)? = nil
  ) throws {
    noteArchiveQueue.async {
      do {
        try self.noteArchive.importFile(
          named: fileName,
          text: text,
          contentChangeDate: contentChangeDate,
          importDate: importDate
        )
        self.notifyObservers(of: self.noteArchive.pageProperties)
        self.invalidateSavedSnippets()
        if let completion = completion {
          DispatchQueue.main.async {
            completion()
          }
        }
      } catch {
        DDLogError("Unexpected error importing file \(fileName): \(error)")
      }
    }
  }

  func importFileMetadataItems(
    _ items: [FileMetadata],
    from metadataProvider: FileMetadataProvider,
    importDate: Date,
    completion: (() -> Void)? = nil
  ) {
    assert(Thread.isMainThread)
    DDLogInfo("Examining \(items.count) file(s) for import...")
    noteArchiveQueue.async {
      let fileImportDates = self.noteArchive.fileImportDates
      DispatchQueue.main.async { [weak self] in
        self?.importFileMetadataItems(
          items,
          from: metadataProvider,
          existingImportDates: fileImportDates,
          importDate: importDate,
          completion: completion
        )
      }
    }
  }
}

private extension NoteArchiveDocument {
  func importFileMetadataItems(
    _ items: [FileMetadata],
    from metadataProvider: FileMetadataProvider,
    existingImportDates: [String: Date],
    importDate: Date,
    completion: (() -> Void)? = nil
  ) {
    assert(Thread.isMainThread)
    let toImport = items
      .filter { $0.fileName.hasSuffix(".txt") }
      .filter { item -> Bool in
        guard let existingDate = existingImportDates[item.fileName] else { return true }
        return !existingDate.withinInterval(1, of: item.contentChangeDate)
      }
    DDLogInfo("Determined we need to import \(toImport.count) file(s)")
    let group = DispatchGroup()
    for item in toImport {
      group.enter()
      metadataProvider.loadText(from: item) { textResult in
        _ = textResult.flatMap({ text -> Void in
          try? self.importFile(
            named: item.fileName,
            text: text,
            contentChangeDate: item.contentChangeDate,
            importDate: importDate,
            completion: { group.leave() }
          )
        })
      }
    }
    group.notify(queue: .main) {
      completion?()
    }
  }
}
