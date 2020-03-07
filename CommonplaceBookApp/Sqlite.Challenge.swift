// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct Challenge: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var index: Int
    var reviewCount: Int = 0
    var lapseCount: Int = 0
    var totalCorrect: Int = 0
    var totalIncorrect: Int = 0
    var lastReview: Date?
    var idealInterval: Double?
    var due: Date?
    var challengeTemplateId: Int64
    var spacedRepetitionFactor: Double = 2.5
    var modifiedDevice: Int64
    var timestamp: Date
    var updateSequenceNumber: Int64

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    enum Columns {
      static let index = Column(CodingKeys.index)
      static let challengeTemplateId = Column(CodingKeys.challengeTemplateId)
      static let due = Column(CodingKeys.due)
      static let modifiedDevice = Column(CodingKeys.modifiedDevice)
      static let timestamp = Column(CodingKeys.timestamp)
      static let updateSequenceNumber = Column(CodingKeys.updateSequenceNumber)
    }

    static let challengeTemplate = belongsTo(ChallengeTemplate.self)

    static let device = belongsTo(Device.self)

    var challengeTemplate: QueryInterfaceRequest<ChallengeTemplate> {
      request(for: Self.challengeTemplate)
    }

    static func createV1Table(in database: Database) throws {
      try database.create(table: "challenge", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("challengeTemplateId", .text)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
      })
    }

    static func createV2Table(in database: Database, named tableName: String) throws {
      try database.create(table: tableName, body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("spacedRepetitionFactor", .double).notNull().defaults(to: 2.5)
        table.column("lapseCount", .double).notNull().defaults(to: 0)
        table.column("idealInterval", .double)
        table.column("challengeTemplateId", .integer)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
      })
    }

    static func createV3Table(in database: Database, named tableName: String) throws {
      try database.create(table: tableName, body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("index", .integer).notNull()
        table.column("reviewCount", .integer).notNull().defaults(to: 0)
        table.column("totalCorrect", .integer).notNull().defaults(to: 0)
        table.column("totalIncorrect", .integer).notNull().defaults(to: 0)
        table.column("lastReview", .datetime)
        table.column("due", .datetime)
        table.column("spacedRepetitionFactor", .double).notNull().defaults(to: 2.5)
        table.column("lapseCount", .double).notNull().defaults(to: 0)
        table.column("idealInterval", .double)
        table.column("challengeTemplateId", .integer)
          .notNull()
          .indexed()
          .references("challengeTemplate", onDelete: .cascade)
        table.column("modifiedDevice", .integer)
          .notNull()
          .indexed()
          .references("device", onDelete: .cascade)
        table.column("timestamp", .datetime)
          .notNull()
      })
      try database.create(index: "byChallengeTemplateIndex", on: tableName, columns: ["index", "challengeTemplateId"], unique: true)
    }

    static func migrateTableFromV1ToV2(in database: Database) throws {
      try database.alter(table: "challenge", body: { table in
        table.add(column: "challengeTemplateFlakeID", .integer).notNull().defaults(to: 0)
      })
      let update = try database.makeUpdateStatement(
        sql: "UPDATE challenge SET challengeTemplateFlakeID = :flakeID WHERE id = :id"
      )
      try database.updateRows(selectSql: "SELECT id, challengeTemplateId FROM challenge", updateStatement: update) { row in
        let id: Int64 = row["id"]
        let challengeTemplateID: String = row["challengeTemplateId"]
        guard let flakeId = try Int.fetchOne(database, ChallengeTemplate.select(sql: "templateFlakeId").filter(key: challengeTemplateID)) else {
          throw MigrationError.cannotFindTemplateID(challengeTemplateID)
        }
        return ["flakeID": flakeId, "id": id]
      }
      try database.rewriteTable(named: "challenge", columns: "id, `index`, reviewCount, totalCorrect, totalIncorrect, lastReview, due, spacedRepetitionFactor, lapseCount, idealInterval, challengeTemplateFlakeID", tableBuilder: { tableName in
        try Self.createV2Table(in: database, named: tableName)
      })
    }

    static func migrateTableFromV2ToV3(in database: Database, currentDeviceID: Int64) throws {
      try database.alter(table: "challenge", body: { table in
        table.add(column: "modifiedDevice", .integer)
        table.add(column: "timestamp", .datetime)
      })
      try updateAll(database, Columns.modifiedDevice <- currentDeviceID)
      try updateAll(database, Columns.timestamp <- Date())
      try database.rewriteTable(named: "challenge", columns: "*", tableBuilder: { tableName in
        try Self.createV3Table(in: database, named: tableName)
      })
    }
  }
}

extension Sqlite.Challenge {
  enum MergeError: Swift.Error {
    case cannotLoadChallenge
  }

  /// Knows how to merge challenges between databases.
  struct MergeInfo: MergeInfoRecord, Decodable {
    // MARK: - Stored properties

    var id: Int64
    var index: Int64
    var challengeTemplateId: Int64
    var timestamp: Date
    var device: Sqlite.Device
    var updateSequenceNumber: Int64

    // MARK: - Computed properties

    static var cursorRequest: QueryInterfaceRequest<Self> {
      Sqlite.Challenge
        .including(required: Sqlite.Challenge.device)
        .asRequest(of: Sqlite.Challenge.MergeInfo.self)
    }

    var instanceRequest: QueryInterfaceRequest<Self> {
      Sqlite.Challenge
        .including(required: Sqlite.Challenge.device)
        .filter(key: ["index": index, "challengeTemplateId": challengeTemplateId])
        .asRequest(of: Sqlite.Challenge.MergeInfo.self)
    }

    var deviceUUID: String { device.uuid }

    func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws {
      guard var originRecord = try Sqlite.Challenge
        .filter(key: ["index": index, "challengeTemplateId": challengeTemplateId])
        .fetchOne(sourceDatabase) else {
        throw MergeError.cannotLoadChallenge
      }
      if let destinationDevice = try Sqlite.Device.filter(Sqlite.Device.Columns.uuid == device.uuid).fetchOne(destinationDatabase) {
        originRecord.modifiedDevice = destinationDevice.id!
      } else {
        var deviceRecord = device
        deviceRecord.id = nil
        deviceRecord.updateSequenceNumber = updateSequenceNumber
        try deviceRecord.insert(destinationDatabase)
        originRecord.modifiedDevice = deviceRecord.id!
      }
      if let destinationRecord = try Sqlite.Challenge.filter(key: ["index": index, "challengeTemplateId": challengeTemplateId]).fetchOne(destinationDatabase) {
        originRecord.id = destinationRecord.id
        try originRecord.update(destinationDatabase)
      } else {
        originRecord.id = nil
        try originRecord.insert(destinationDatabase)
      }
    }
  }
}
