// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB
import Logging

private enum ApplicationMimeType: String {
  /// Private MIME type for URLs.
  case url = "text/vnd.grail.url"
}

public extension Note {
  /// Loads a note from the database.
  init(identifier: Note.Identifier, database db: Database) throws {
    guard
      let sqliteNote = try NoteRecord.fetchOne(db, key: identifier),
      !sqliteNote.deleted
    else {
      throw NoteDatabase.Error.noSuchNote
    }
    let hashtagRecords = try NoteLinkRecord.filter(NoteLinkRecord.Columns.noteId == identifier).fetchAll(db)
    let hashtags = hashtagRecords.map { $0.targetTitle }
    let contentRecords = try ContentRecord.filter(ContentRecord.Columns.noteId == identifier).fetchAll(db)
    let tuples = try contentRecords
      .filter { $0.role.hasPrefix("prompt=") }
      .map { (key: $0.key, value: try $0.asPromptCollection()) }
    let promptCollections = Dictionary(uniqueKeysWithValues: tuples)
    let noteText = contentRecords.first(where: { $0.role == "primary" })?.text

    self.init(
      creationTimestamp: sqliteNote.creationTimestamp,
      timestamp: sqliteNote.modifiedTimestamp,
      hashtags: hashtags,
      title: sqliteNote.title,
      text: noteText,
      reference: try db.reference(for: identifier),
      promptCollections: promptCollections
    )
  }

  // TODO: Make this smaller
  // swiftlint:disable:next function_body_length
  func save(identifier: Note.Identifier, updateKey: UpdateIdentifier, to db: Database) throws {
    let sqliteNote = NoteRecord(
      id: identifier,
      title: title,
      creationTimestamp: creationTimestamp,
      modifiedTimestamp: timestamp,
      modifiedDevice: updateKey.deviceID,
      deleted: false,
      updateSequenceNumber: updateKey.updateSequenceNumber
    )
    try sqliteNote.save(db)

    try savePrimaryText(noteIdentifier: identifier, database: db)
    try saveReference(noteIdentifier: identifier, database: db)
    let inMemoryHashtags = Set(hashtags)
    let onDiskHashtags = ((try? sqliteNote.hashtags.fetchAll(db)) ?? [])
      .asSet()
    for newHashtag in inMemoryHashtags.subtracting(onDiskHashtags) {
      let associationRecord = NoteLinkRecord(noteId: identifier, targetTitle: newHashtag)
      try associationRecord.save(db)
    }
    for obsoleteHashtag in onDiskHashtags.subtracting(inMemoryHashtags) {
      let deleted = try NoteLinkRecord.deleteOne(db, key: ["noteId": identifier, "targetTitle": obsoleteHashtag])
      assert(deleted)
    }

    let inMemoryContentKeys = Set(promptCollections.keys)
    let onDiskContentKeys = ((try? sqliteNote.prompts.fetchAll(db)) ?? [])
      .map { $0.key }
      .asSet()

    let today = Date()
    for newKey in inMemoryContentKeys.subtracting(onDiskContentKeys) {
      let promptCollection = promptCollections[newKey]!
      let record = ContentRecord(
        text: promptCollection.rawValue,
        noteId: identifier,
        key: newKey,
        role: promptCollection.type.rawValue,
        mimeType: "text/markdown"
      )
      do {
        try record.insert(db)
      } catch {
        Logger.shared.critical("Could not insert content")
        throw error
      }
      for index in promptCollection.prompts.indices {
        let promptStatistics = PromptRecord(
          noteId: identifier,
          promptKey: newKey,
          promptIndex: Int64(index),
          due: today.addingTimeInterval(promptCollection.newPromptDelay.fuzzed()),
          modifiedDevice: updateKey.deviceID,
          timestamp: timestamp,
          updateSequenceNumber: updateKey.updateSequenceNumber
        )
        try promptStatistics.insert(db)
      }
    }
    for modifiedKey in inMemoryContentKeys.intersection(onDiskContentKeys) {
      let promptCollection = promptCollections[modifiedKey]!
      guard var record = try ContentRecord.fetchOne(db, key: ContentRecord.primaryKey(noteId: identifier, key: modifiedKey)) else {
        assertionFailure("Should be a record")
        continue
      }
      record.text = promptCollection.rawValue
      try record.update(db, columns: [ContentRecord.Columns.text])
    }
    for obsoleteKey in onDiskContentKeys.subtracting(inMemoryContentKeys) {
      let deleted = try ContentRecord.deleteOne(db, key: ContentRecord.primaryKey(noteId: identifier, key: obsoleteKey))
      assert(deleted)
    }
  }

  private func savePrimaryText(noteIdentifier: Note.Identifier, database db: Database) throws {
    guard let noteText = text else { return }
    let newRecord = ContentRecord(
      text: noteText,
      noteId: noteIdentifier,
      key: "primary",
      role: "primary",
      mimeType: "text/markdown"
    )
    try newRecord.save(db)
  }

  private func saveReference(noteIdentifier: Note.Identifier, database: Database) throws {
    guard let reference = reference else { return }
    switch reference {
    case .webPage(let url):
      let record = ContentRecord(
        text: url.absoluteString,
        noteId: noteIdentifier,
        key: ContentRole.reference.rawValue,
        role: ContentRole.reference.rawValue,
        mimeType: ApplicationMimeType.url.rawValue
      )
      try record.save(database)
    }
  }
}

private extension Database {
  func reference(for noteIdentifier: Note.Identifier) throws -> Note.Reference? {
    guard
      let record = try ContentRecord
      .filter(ContentRecord.Columns.noteId == noteIdentifier)
      .filter(ContentRecord.Columns.role == ContentRole.reference.rawValue).fetchOne(self)
    else {
      return nil
    }
    let mimeType = ApplicationMimeType(rawValue: record.mimeType)
    switch mimeType {
    case .none:
      Logger.shared.error("Unrecognized reference MIME type \(record.mimeType), ignoring")
      return nil
    case .url:
      if let url = URL(string: record.text) {
        return .webPage(url)
      } else {
        Logger.shared.error("Could not turn string into URL: \(record.text)")
        return nil
      }
    }
  }
}
