// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Foundation
import GRDB
import KeyValueCRDT
import os

private extension OSLog {
  static let studySession = OSLog(subsystem: "org.brians-brain.NoteDatabase", category: "studySession")
}

/// Observes a database and maintains the data needed to generate study sessions.
public actor SessionGenerator {
  public init(database: NoteDatabase) {
    self.database = database
  }

  private let database: NoteDatabase

  public func startMonitoringDatabase() throws {
//    let results = try database.bulkRead(isIncluded: { _, key in
//      key.hasPrefix("prompt=") || key == NoteDatabaseKey.metadata.rawValue
//    })
//    for result in results {
//      processValue(scopedKey: result.key, versions: result.value)
//    }
//    valueSubscription = database.updatedValuesPublisher.sink(receiveValue: { [weak self] scopedKey, versions in
//      self?.asyncProcessValue(scopedKey: scopedKey, versions: versions)
//    })
  }

  public func studySession(noteIdentifiers: Set<Note.Identifier>? = nil, date: Date) throws -> StudySession {
    let signpostID = OSSignpostID(log: .studySession)
    os_signpost(.begin, log: .studySession, name: "makeStudySession", signpostID: signpostID)
    let sqlLiteral = StudySessionEntryRecord.sql(identifiers: noteIdentifiers, due: date)
    let entries = try database.keyValueCRDT.read { db -> [StudySessionEntryRecord] in
      let (sql, arguments) = try sqlLiteral.build(db)
      return try StudySessionEntryRecord.fetchAll(db, sql: sql, arguments: arguments)
    }
    var studySession = StudySession()
    for entry in entries {
      guard let metadata = database.bookMetadata(identifier: entry.scope) else { continue }
      studySession.append(
        promptIdentifier: entry.promptIdentifier,
        properties: CardDocumentProperties(documentName: entry.scope, attributionMarkdown: metadata.preferredTitle)
      )
    }
    os_signpost(.end, log: .studySession, name: "makeStudySession", signpostID: signpostID)
    return studySession
  }
}

struct StudySessionEntryRecord: FetchableRecord, Codable {

  var scope: Note.Identifier
  var key: String
  var promptIndex: Int
  var title: String?
  var due: Date?

  var promptIdentifier: PromptIdentifier {
    PromptIdentifier(noteId: scope, promptKey: key, promptIndex: promptIndex)
  }

  static func sql(identifiers: Set<Note.Identifier>?, due: Date) -> SQL {
    let dueString = ISO8601DateFormatter().string(from: due)
    var baseSQL: SQL = """
    SELECT
        entry.scope AS scope,
        entry.key AS KEY,
        promptStatistics.key AS promptIndex,
        coalesce(
            json_extract(metadata.json, '$.book.title'),
            json_extract(metadata.json, '$.title')
        ) AS title,
        json_extract(promptStatistics.value, '$.due') AS due
    FROM
        entry
        JOIN json_each(entry.json, '$.promptStatistics') AS promptStatistics
        JOIN entry metadata ON (
            metadata.scope = entry.scope
            AND metadata.key = '.metadata'
        )
    WHERE
        (
            due IS NULL
            OR due <= \(dueString)
        )
    """
    if let identifiers = identifiers {
      baseSQL += " AND scope IN \(identifiers)"
    }
    return baseSQL + " ORDER BY due"
  }
}
