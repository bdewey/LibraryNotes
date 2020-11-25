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

extension Sqlite {
  /// Core record for the `note` table
  struct Note: Codable, FetchableRecord, PersistableRecord {
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

    static let noteHashtags = hasMany(NoteHashtag.self)

    var hashtags: QueryInterfaceRequest<String> {
      NoteHashtag
        .filter(NoteHashtag.Columns.noteId == id.rawValue)
        .select(NoteHashtag.Columns.hashtag, as: String.self)
    }

    static let challengeTemplates = hasMany(ChallengeTemplate.self)
    var challengeTemplates: QueryInterfaceRequest<ChallengeTemplate> { request(for: Note.challengeTemplates) }

    /// The association between this note and its text.
    static let noteText = hasOne(NoteText.self)

    /// A query that returns the text associated with this note.
    var noteText: QueryInterfaceRequest<NoteText> { request(for: Note.noteText) }

    static let challenges = hasMany(Challenge.self, through: challengeTemplates, using: ChallengeTemplate.challenges)
    var challenges: QueryInterfaceRequest<Challenge> { request(for: Note.challenges) }

    /// The association between this note and the device it was last changed on.
    static let device = belongsTo(Device.self)
  }
}

extension Sqlite.Note {
  /// Knows how to merge notes between a local and remote database.
  struct MergeInfo: MergeInfoRecord, Decodable {
    // MARK: - Stored properties

    var id: FlakeID
    var modifiedTimestamp: Date
    var device: Sqlite.Device
    var updateSequenceNumber: Int64

    // MARK: - Computed properties

    static var cursorRequest: QueryInterfaceRequest<Self> {
      Sqlite.Note
        .including(required: Sqlite.Note.device)
        .asRequest(of: Sqlite.Note.MergeInfo.self)
    }

    var instanceRequest: QueryInterfaceRequest<Self> {
      Sqlite.Note
        .including(required: Sqlite.Note.device)
        .filter(key: id.rawValue)
        .asRequest(of: Sqlite.Note.MergeInfo.self)
    }

    var timestamp: Date { modifiedTimestamp }
    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard
        var note = try Sqlite.Note.filter(key: id.rawValue).fetchOne(sourceDatabase)
      else {
        return
      }
      if let device = try Sqlite.Device.filter(key: ["uuid": device.uuid]).fetchOne(destinationDatabase) {
        note.modifiedDevice = device.id!
      } else {
        var device = self.device
        device.id = nil
        device.updateSequenceNumber = updateSequenceNumber
        try device.insert(destinationDatabase)
        note.modifiedDevice = device.id!
      }

      try Sqlite.Note.deleteOne(destinationDatabase, key: id.rawValue)
      try note.insert(destinationDatabase)
      try note.hashtags.fetchAll(sourceDatabase).forEach { hashtag in
        let record = Sqlite.NoteHashtag(noteId: id, hashtag: hashtag)
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
