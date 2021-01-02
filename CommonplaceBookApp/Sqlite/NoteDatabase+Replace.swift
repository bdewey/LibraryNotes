//
//  NoteDatabase+Replace.swift
//  CommonplaceBookApp
//
//  Created by Brian Dewey on 1/1/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import GRDB

extension NoteDatabase {
  /// Does a global replacement of `originalText` with `replacementText` across all notes in a single transaction.
  public func replaceText(_ originalText: String, with replacementText: String) throws {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }
    try dbQueue.write { database in
      let updateKey = try updateIdentifier(in: database)
      let metadata = try Self.fetchAllMetadata(from: database)
      for identifier in metadata.keys {
        let note = try Note(identifier: identifier, database: database)
        if let text = note.text {
          let updatedNote = Note(markdown: text.replacingOccurrences(of: originalText, with: replacementText))
          try updatedNote.save(identifier: identifier, updateKey: updateKey, to: database)
        }
      }
    }
  }
}
