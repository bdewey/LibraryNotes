// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB
import Logging
import TextMarkupKit

public extension NoteDatabase {
  /// Does a global replacement of `originalText` with `replacementText` across all notes in a single transaction.
  func replaceText(
    _ originalText: String,
    with replacementText: String,
    filter: (NoteMetadataRecord) -> Bool = { _ in true }
  ) throws {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }
    try dbQueue.write { database in
      let updateKey = try updateIdentifier(in: database)
      let allMetadata = try Self.fetchAllMetadata(from: database)
      for (identifier, metadata) in allMetadata where filter(metadata) {
        var note = try Note(identifier: identifier, database: database)
        if let text = note.text {
          note.updateMarkdown(text.replacingOccurrences(of: originalText, with: replacementText))
          try note.save(identifier: identifier, updateKey: updateKey, to: database)
        }
      }
    }
  }

  /// Renames a hashtag. Note this isn't just a search-and-replace, because renaming `#book` to `#books` should not affect anything already tagged `#books`
  func renameHashtag(
    _ originalHashtag: String,
    to newHashtag: String,
    filter: (NoteMetadataRecord) -> Bool = { _ in true }
  ) throws {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }
    try dbQueue.write { database in
      let updateKey = try updateIdentifier(in: database)
      let allMetadata = try Self.fetchAllMetadata(from: database)
      for (identifier, metadata) in allMetadata where filter(metadata) {
        var note = try Note(identifier: identifier, database: database)
        if let text = note.text {
          let parsedText = ParsedString(text, grammar: MiniMarkdownGrammar.shared)
          guard let root = try? parsedText.result.get() else { continue }
          var replacementLocations = [Int]()
          root.forEach { node, startIndex, _ in
            guard node.type == .hashtag else { return }
            let range = NSRange(location: startIndex, length: node.length)
            let hashtag = String(utf16CodeUnits: parsedText[range], count: range.length)
            if originalHashtag.isPathPrefix(of: hashtag) {
              replacementLocations.append(startIndex)
            }
          }
          let originalHashtagLength = originalHashtag.utf16.count
          for location in replacementLocations.reversed() {
            parsedText.replaceCharacters(in: NSRange(location: location, length: originalHashtagLength), with: newHashtag)
          }
          note.updateMarkdown(parsedText.string)
          try note.save(identifier: identifier, updateKey: updateKey, to: database)
        }
      }
    }
  }

  func moveNotesTaggedWithHashtag(_ hashtag: String, to folder: String?) throws {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }
    try dbQueue.write { database in
      let updateKey = try updateIdentifier(in: database)
      let records = try NoteRecord
        .joining(required: NoteRecord.noteHashtags.filter(NoteLinkRecord.Columns.targetTitle.like("\(hashtag)%")))
        .filter(NoteRecord.Columns.folder == nil)
        .fetchAll(database)
      for record in records {
        var record = record
        record.modifiedDevice = updateKey.deviceID
        record.updateSequenceNumber = updateKey.updateSequenceNumber
        record.folder = folder
        try record.update(database)
      }
    }
  }
}
