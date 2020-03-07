// Copyright © 2017-present Brian's Brain. All rights reserved.

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
        table.column("id", .text).primaryKey()
        table.column("title", .text).notNull().defaults(to: "")
        table.column("modifiedTimestamp", .datetime).notNull()
        table.column("hasText", .boolean).notNull()
      })
    }

    static func createV2Table(in database: Database, named name: String = "note") throws {
      try database.create(table: name, body: { table in
        table.column("id", .integer).primaryKey()
        table.column("title", .text).notNull().defaults(to: "")
        table.column("modifiedTimestamp", .datetime).notNull()
        table.column("modifiedDevice", .integer).indexed().references("device", onDelete: .setNull)
        table.column("hasText", .boolean).notNull()
      })
    }

    static func migrateTableFromV1ToV2(in database: Database, flakeMaker: FlakeMaker) throws {
      try database.alter(table: "note", body: { table in
        // This should be unique & indexed, but it can't start that way because we can't
        // assign the right values to it.
        table.add(column: "createID", .integer).notNull().defaults(to: 0)
        table.add(column: "modifiedDevice", .integer).defaults(to: flakeMaker.instanceNumber)
      })
      try assignFlakeIDToAllRecords(in: database, flakeMaker: flakeMaker)
      try NoteText.migrateTableFromV1ToV2(in: database, flakeMaker: flakeMaker)
      try NoteHashtag.migrateTableFromV1ToV2(in: database)
      try ChallengeTemplate.migrateTableFromV1ToV2(in: database, flakeMaker: flakeMaker)
      try database.rewriteTable(named: "note", columns: "createID, title, modifiedTimestamp, modifiedDevice, hasText", tableBuilder: { newName in
        try Self.createV2Table(in: database, named: newName)
      })
    }

    private static func assignFlakeIDToAllRecords(in database: Database, flakeMaker: FlakeMaker) throws {
      let ids = try String.fetchAll(database, sql: "SELECT id FROM note")
      let flakeUpdate = try database.makeUpdateStatement(sql: "UPDATE note SET createID = :createID WHERE id = :id")
      for id in ids {
        try flakeUpdate.execute(arguments: ["id": id, "createID": flakeMaker.nextValue().rawValue])
      }
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
