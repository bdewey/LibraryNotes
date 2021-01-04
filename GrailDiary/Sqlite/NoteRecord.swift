// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// Core record for the `note` table
struct NoteRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "Note"
  var id: Note.Identifier
  var title: String
  var creationTimestamp: Date
  var modifiedTimestamp: Date
  var modifiedDevice: String
  var deleted: Bool
  var updateSequenceNumber: Int64

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let title = Column(CodingKeys.title)
    static let modifiedTimestamp = Column(CodingKeys.modifiedTimestamp)
    static let deleted = Column(CodingKeys.deleted)
  }

  static let noteHashtags = hasMany(NoteLinkRecord.self)

  var hashtags: QueryInterfaceRequest<String> {
    NoteLinkRecord
      .filter(NoteLinkRecord.Columns.noteId == id)
      .select(NoteLinkRecord.Columns.targetTitle, as: String.self)
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

  static var binaryContentRecords = hasMany(BinaryContentRecord.self)

  var binaryContentRecords: QueryInterfaceRequest<BinaryContentRecord> { request(for: Self.binaryContentRecords) }

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
        let record = NoteLinkRecord(noteId: id, targetTitle: hashtag)
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
