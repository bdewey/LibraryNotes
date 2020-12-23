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

/// Core record for the `note` table
struct NoteRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "Note"
  var id: Note.Identifier
  var title: String
  var modifiedTimestamp: Date
  var modifiedDevice: String
  var hasText: Bool
  var deleted: Bool
  var updateSequenceNumber: Int64

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let title = Column(CodingKeys.title)
    static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    static let deleted = Column(CodingKeys.deleted)
  }

  static let noteHashtags = hasMany(NoteHashtagRecord.self)

  var hashtags: QueryInterfaceRequest<String> {
    NoteHashtagRecord
      .filter(NoteHashtagRecord.Columns.noteId == id)
      .select(NoteHashtagRecord.Columns.hashtag, as: String.self)
  }

  static var contentRecords = hasMany(ContentRecord.self)

  var contentRecords: QueryInterfaceRequest<ContentRecord> { request(for: Self.contentRecords) }

  var prompts: QueryInterfaceRequest<ContentRecord> {
    request(for: Self.contentRecords).filter(ContentRecord.Columns.role.like("prompt=%"))
  }

  /// A query that returns the text associated with this note.
  var noteText: QueryInterfaceRequest<ContentRecord> {
    request(for: Self.contentRecords).filter(ContentRecord.Columns.role == "primary")
  }

  static let promptStatistics = hasMany(PromptRecord.self, through: contentRecords, using: ContentRecord.promptStatistics)

  var promptStatistics: QueryInterfaceRequest<PromptRecord> {
    request(for: Self.promptStatistics)
  }

  /// The association between this note and the device it was last changed on.
  static let device = belongsTo(DeviceRecord.self)
}

extension NoteRecord {
  /// Knows how to merge notes between a local and remote database.
  struct MergeInfo: MergeInfoRecord, Decodable {
    // MARK: - Stored properties

    var id: String
    var modifiedTimestamp: Date
    var device: DeviceRecord
    var updateSequenceNumber: Int64

    // MARK: - Computed properties

    static var cursorRequest: QueryInterfaceRequest<Self> {
      NoteRecord
        .including(required: NoteRecord.device)
        .asRequest(of: NoteRecord.MergeInfo.self)
    }

    var instanceRequest: QueryInterfaceRequest<Self> {
      NoteRecord
        .including(required: NoteRecord.device)
        .filter(key: id)
        .asRequest(of: NoteRecord.MergeInfo.self)
    }

    var timestamp: Date { modifiedTimestamp }
    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard
        let note = try NoteRecord.filter(key: id).fetchOne(sourceDatabase)
      else {
        return
      }
      if (try DeviceRecord.filter(key: ["uuid": device.uuid]).fetchOne(destinationDatabase)) == nil {
        // Make a device record in the destination database.
        var device = self.device
        device.updateSequenceNumber = updateSequenceNumber
        try device.insert(destinationDatabase)
      }

      try NoteRecord.deleteOne(destinationDatabase, key: id)
      try note.insert(destinationDatabase)
      try note.hashtags.fetchAll(sourceDatabase).forEach { hashtag in
        let record = NoteHashtagRecord(noteId: id, hashtag: hashtag)
        try record.insert(destinationDatabase)
      }
      try note.contentRecords.fetchAll(sourceDatabase).forEach { contentRecord in
        try contentRecord.insert(destinationDatabase)
      }
      try note.promptStatistics.fetchAll(sourceDatabase).forEach { promptStatisticsRecord in
        try promptStatisticsRecord.insert(destinationDatabase)
      }
    }
  }
}
