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

enum ContentRole: String, Codable {
  case primary
}

/// For rows that contain text, this is the text.
struct ContentRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "content"
  var text: String
  var noteId: String
  var key: String
  var role: String
  var mimeType: String

  enum Columns: String, ColumnExpression {
    case text
    case noteId
    case key
    case role
    case mimeType
  }

  static let promptStatistics = hasMany(PromptStatistics.self)

  static func fetchOne(_ database: Database, key: ChallengeTemplate.Identifier) throws -> ContentRecord? {
    try fetchOne(database, key: key.keyArray)
  }

  @discardableResult
  static func deleteOne(_ database: Database, key: ChallengeTemplate.Identifier) throws -> Bool {
    try deleteOne(database, key: key.keyArray)
  }
}

private extension ChallengeTemplate.Identifier {
  var keyArray: [String: DatabaseValueConvertible] {
    [ContentRecord.Columns.noteId.rawValue: noteId, ContentRecord.Columns.key.rawValue: promptKey]
  }
}
