//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import GRDB

public extension NoteDatabase {
  /// Does a global replacement of `originalText` with `replacementText` across all notes in a single transaction.
  func replaceText(
    _ originalText: String,
    with replacementText: String,
    filter: (Note.Metadata) -> Bool = { _ in true }
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
}
