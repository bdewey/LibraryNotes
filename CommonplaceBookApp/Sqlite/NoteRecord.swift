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
  var id: FlakeID
  var title: String
  var modifiedTimestamp: Date
  var modifiedDevice: Int64
  var hasText: Bool
  var deleted: Bool
  var updateSequenceNumber: Int64

  static func createV1Table(in database: Database) throws {
    try database.create(table: "note", body: { table in
      table.column("id", .integer).primaryKey()
      table.column("title", .text).notNull().defaults(to: "")
      table.column("modifiedTimestamp", .datetime).notNull()
      table.column("modifiedDevice", .integer).indexed().references("device", onDelete: .setNull)
      table.column("hasText", .boolean).notNull()
      table.column("deleted", .boolean).notNull().defaults(to: false)
      table.column("updateSequenceNumber", .integer).notNull()
    })
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let title = Column(CodingKeys.title)
    static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    static let deleted = Column(CodingKeys.deleted)
  }

  static let noteHashtags = hasMany(NoteHashtagRecord.self)

  var hashtags: QueryInterfaceRequest<String> {
    NoteHashtagRecord
      .filter(NoteHashtagRecord.Columns.noteId == id.rawValue)
      .select(NoteHashtagRecord.Columns.hashtag, as: String.self)
  }

  static let challengeTemplates = hasMany(ChallengeTemplateRecord.self)
  var challengeTemplates: QueryInterfaceRequest<ChallengeTemplateRecord> { request(for: NoteRecord.challengeTemplates) }

  /// The association between this note and its text.
  static let noteText = hasOne(NoteTextRecord.self)

  /// A query that returns the text associated with this note.
  var noteText: QueryInterfaceRequest<NoteTextRecord> { request(for: NoteRecord.noteText) }

  static let challenges = hasMany(ChallengeRecord.self, through: challengeTemplates, using: ChallengeTemplateRecord.challenges)
  var challenges: QueryInterfaceRequest<ChallengeRecord> { request(for: NoteRecord.challenges) }

  /// The association between this note and the device it was last changed on.
  static let device = belongsTo(DeviceRecord.self)
}

extension NoteRecord {
  /// Knows how to merge notes between a local and remote database.
  struct MergeInfo: MergeInfoRecord, Decodable {
    // MARK: - Stored properties

    var id: FlakeID
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
        .filter(key: id.rawValue)
        .asRequest(of: NoteRecord.MergeInfo.self)
    }

    var timestamp: Date { modifiedTimestamp }
    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard
        var note = try NoteRecord.filter(key: id.rawValue).fetchOne(sourceDatabase)
      else {
        return
      }
      if let device = try DeviceRecord.filter(key: ["uuid": device.uuid]).fetchOne(destinationDatabase) {
        note.modifiedDevice = device.id!
      } else {
        var device = self.device
        device.id = nil
        device.updateSequenceNumber = updateSequenceNumber
        try device.insert(destinationDatabase)
        note.modifiedDevice = device.id!
      }

      try NoteRecord.deleteOne(destinationDatabase, key: id.rawValue)
      try note.insert(destinationDatabase)
      try note.hashtags.fetchAll(sourceDatabase).forEach { hashtag in
        let record = NoteHashtagRecord(noteId: id, hashtag: hashtag)
        try record.insert(destinationDatabase)
      }
      try note.noteText.fetchAll(sourceDatabase).forEach { noteText in
        var noteText = noteText
        noteText.id = nil
        try noteText.insert(destinationDatabase)
      }
      try note.challengeTemplates.fetchAll(sourceDatabase).forEach { challengeTemplate in
        try challengeTemplate.insert(destinationDatabase)
      }
      try note.challenges.fetchAll(sourceDatabase).forEach { challenge in
        var challenge = challenge
        challenge.id = nil
        try challenge.insert(destinationDatabase)
      }
    }
  }
}
