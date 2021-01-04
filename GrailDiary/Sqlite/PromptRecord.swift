// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

struct PromptRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "prompt"
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
  static func fetchOne(_ database: Database, key: PromptIdentifier) throws -> PromptRecord? {
    return try fetchOne(database, key: [
      Columns.noteId.rawValue: key.noteId,
      Columns.promptKey.rawValue: key.promptKey,
      Columns.promptIndex.rawValue: key.promptIndex,
    ])
  }
}

extension PromptRecord {
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
      PromptRecord
        .including(required: PromptRecord.device)
        .asRequest(of: PromptRecord.MergeInfo.self)
    }

    var instanceRequest: QueryInterfaceRequest<Self> {
      PromptRecord
        .including(required: PromptRecord.device)
        .filter(key: ["noteId": noteId, "promptKey": promptKey, "promptIndex": promptIndex])
        .asRequest(of: PromptRecord.MergeInfo.self)
    }

    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard let originRecord = try PromptRecord
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
