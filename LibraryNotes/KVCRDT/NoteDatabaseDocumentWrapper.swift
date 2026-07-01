// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import Foundation
import KeyValueCRDT
import os
import UIKit

/// UIKit document wrapper for a Library Notes database.
@MainActor
public final class NoteDatabaseDocumentWrapper {
  public init(fileURL: URL, authorDescription: String) async throws {
    let keyValueDocument = try UIKeyValueDocument(
      fileURL: fileURL,
      authorDescription: authorDescription,
      upgrader: .noteDatabaseUpgrader
    )
    guard await keyValueDocument.open(), let keyValueCRDT = keyValueDocument.keyValueCRDT else {
      throw NoteDatabaseError.databaseIsNotOpen
    }
    self.keyValueDocument = keyValueDocument
    self.database = NoteDatabase(
      keyValueCRDT: keyValueCRDT,
      fileURL: fileURL,
      documentActions: NoteDatabaseDocumentActions(
        refresh: {
          try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        },
        flush: {
          _ = await keyValueDocument.save(to: fileURL, for: .forOverwriting)
        }
      )
    )
    keyValueDocument.delegate = self
  }

  private let keyValueDocument: UIKeyValueDocument

  public let database: NoteDatabase

  public var fileURL: URL { keyValueDocument.fileURL }

  public var documentState: UIDocument.State { keyValueDocument.documentState }

  public var hasUnsavedChanges: Bool { keyValueDocument.hasUnsavedChanges }

  public func close() async -> Bool {
    await keyValueDocument.close()
  }

  public func save(to url: URL, for saveOperation: UIDocument.SaveOperation) async -> Bool {
    await keyValueDocument.save(to: url, for: saveOperation)
  }

  public func refresh() throws {
    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
  }

  public func flush() async throws {
    _ = await keyValueDocument.save(to: fileURL, for: .forOverwriting)
  }

  public func merge(other: NoteDatabaseDocumentWrapper) throws {
    try database.merge(other: other.database)
  }
}

extension NoteDatabaseDocumentWrapper: UIKeyValueDocumentDelegate {
  public nonisolated func keyValueDocument(_ document: UIKeyValueDocument, willMergeCRDT sourceCRDT: KeyValueDatabase, into destinationCRDT: KeyValueDatabase) {
    do {
      let documentsDirectoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let mergeDirectoryURL = documentsDirectoryURL.appendingPathComponent("merge-attempts")
      let creationDate = Date()
      let unwantedCharacters = CharacterSet(charactersIn: "-:")
      var uniqifier = ISO8601DateFormatter().string(from: creationDate)
      uniqifier.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })

      let containerURL = mergeDirectoryURL.appendingPathComponent("merge-\(uniqifier)")
      Logger.shared.info("Making a backup to \(containerURL)")
      try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
      let inMemoryURL = containerURL.appendingPathComponent("memory.sqlite")
      try destinationCRDT.save(to: inMemoryURL)
      let onDiskURL = containerURL.appendingPathComponent("disk.sqlite")
      try sourceCRDT.save(to: onDiskURL)
    } catch {
      Logger.shared.error("Unexpected error making backup: \(error)")
    }
  }
}
