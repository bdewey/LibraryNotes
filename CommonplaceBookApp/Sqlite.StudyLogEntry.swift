// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Sqlite {
  struct StudyLogEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var timestamp: Date
    var correct: Int
    var incorrect: Int
    var challengeId: Int64

    mutating func didInsert(with rowID: Int64, for column: String?) {
      id = rowID
    }

    static func createV1Table(in database: Database) throws {
      try database.create(table: "studyLogEntry", body: { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("timestamp", .datetime).notNull()
        table.column("correct", .integer).notNull().defaults(to: 0)
        table.column("incorrect", .integer).notNull().defaults(to: 0)
        table.column("challengeId", .integer)
          .notNull()
          .references("challenge", onDelete: .cascade)
      })
    }

    enum Columns {
      static let timestamp = Column(StudyLogEntry.CodingKeys.timestamp)
    }

    static let challenge = belongsTo(Challenge.self)
  }
}
