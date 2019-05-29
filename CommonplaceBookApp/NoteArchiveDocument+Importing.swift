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
    importDate: Date
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
      } catch {
        DDLogError("Unexpected error importing file \(fileName): \(error)")
      }
    }
  }

  func importFileMetadataItems(
    _ items: [FileMetadata],
    from metadataProvider: FileMetadataProvider,
    importDate: Date
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
          importDate: importDate
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
    importDate: Date
  ) {
    assert(Thread.isMainThread)
    let toImport = items
      .filter { $0.fileName.hasSuffix(".txt") }
      .filter { item -> Bool in
        guard let existingDate = existingImportDates[item.fileName] else { return true }
        return !existingDate.withinInterval(1, of: item.contentChangeDate)
      }
    DDLogInfo("Determined we need to import \(toImport.count) file(s)")
    for item in toImport {
      metadataProvider.loadText(from: item) { textResult in
        _ = textResult.flatMap({ text -> Void in
          try? self.importFile(
            named: item.fileName,
            text: text,
            contentChangeDate: item.contentChangeDate,
            importDate: importDate
          )
        })
      }
    }
  }
}
