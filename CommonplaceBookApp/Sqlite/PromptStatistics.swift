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

struct PromptStatistics: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "promptCounters"
  var noteId: String
  var promptKey: String
  var promptIndex: Int64
  var reviewCount: Int = 0
  var lapseCount: Int = 0
  var totalCorrect: Int = 0
  var totalIncorrect: Int = 0
  var lastReview: Date?
  var idealInterval: Double?
  var due: Date?
  var spacedRepetitionFactor: Double = 2.5
  var modifiedDevice: String
  var timestamp: Date
  var updateSequenceNumber: Int64

  enum Columns: String, ColumnExpression {
    case due, noteId, promptKey, promptIndex, modifiedDevice, updateSequenceNumber
  }

  static let device = belongsTo(DeviceRecord.self)

  /// Convenience method that knows how to unpack a `PromptIdentifier` into the primary keys for a PromptStatistics.
  static func fetchOne(_ database: Database, key: PromptIdentifier) throws -> PromptStatistics? {
    return try fetchOne(database, key: [
      Columns.noteId.rawValue: key.noteId,
      Columns.promptKey.rawValue: key.promptKey,
      Columns.promptIndex.rawValue: key.promptIndex,
    ])
  }
}

extension PromptStatistics {
  enum MergeError: Swift.Error {
    case cannotLoadPrompt
  }

  /// Knows how to merge prompt statistics between databases.
  struct MergeInfo: MergeInfoRecord, Decodable {
    // MARK: - Stored properties

    var noteId: String
    var promptKey: String
    var promptIndex: Int64
    var timestamp: Date
    var device: DeviceRecord
    var updateSequenceNumber: Int64

    // MARK: - Computed properties

    static var cursorRequest: QueryInterfaceRequest<Self> {
      PromptStatistics
        .including(required: PromptStatistics.device)
        .asRequest(of: PromptStatistics.MergeInfo.self)
    }

    var instanceRequest: QueryInterfaceRequest<Self> {
      PromptStatistics
        .including(required: PromptStatistics.device)
        .filter(key: ["noteId": noteId, "promptKey": promptKey, "promptIndex": promptIndex])
        .asRequest(of: PromptStatistics.MergeInfo.self)
    }

    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard let originRecord = try PromptStatistics
        .filter(key: ["noteId": noteId, "promptKey": promptKey, "promptIndex": promptIndex])
        .fetchOne(sourceDatabase)
      else {
        throw MergeError.cannotLoadPrompt
      }
      if (try DeviceRecord.filter(DeviceRecord.Columns.uuid == device.uuid).fetchOne(destinationDatabase)) == nil {
        // We don't have a device record for this device in the destination database. Insert one.
        var deviceRecord = device
        deviceRecord.updateSequenceNumber = updateSequenceNumber
        try deviceRecord.insert(destinationDatabase)
      }
      try originRecord.save(destinationDatabase)
    }
  }
}
