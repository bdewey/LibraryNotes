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

enum Sqlite {
  enum MigrationError: Error {
    case cannotFindNoteID(String)
    case cannotFindTemplateID(String)
  }

  /// Result structure from fetching a Note plus all of its hashtags
  struct NoteMetadata: Decodable, FetchableRecord {
    var id: Int64
    var title: String
    var modifiedTimestamp: Date
    var hasText: Bool
    var deleted: Bool
    var noteHashtags: [NoteHashtag]

    static let request = NoteRecord.including(all: NoteRecord.noteHashtags)
  }

  /// Includes all of the information needed to convert a Sqlite.StudyLogEntry to an in-memory StudyLog.entry.
  struct StudyLogEntryInfo: Codable, FetchableRecord {
    var studyLogEntry: StudyLogEntry
    var challenge: ChallengeRecord
  }
}
