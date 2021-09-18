// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Foundation
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
  private var valueSubscription: AnyCancellable?

  // TODO: "Make it right, then make it fast"
  // The main perf win from having the SessionGenerator is avoiding re-parsing the entire set of prompts when any prompt changes.
  // The prompts & metadata are then put into naïve, unsorted arrays. Once this becomes a perf bottleneck, switch this to
  // something more sophisticated
  private var entries: [Entry] = []
  private var metadata: [Note.Identifier: BookNoteMetadata] = [:]

  public func startMonitoringDatabase() throws {
    let results = try database.bulkRead(isIncluded: { _, key in
      key.hasPrefix("prompt=") || key == NoteDatabaseKey.metadata.rawValue
    })
    for result in results {
      processValue(scopedKey: result.key, versions: result.value)
    }
    valueSubscription = database.updatedValuesPublisher.sink(receiveValue: { [weak self] scopedKey, versions in
      self?.asyncProcessValue(scopedKey: scopedKey, versions: versions)
    })
  }

  public func studySession(filter: ((Note.Identifier, BookNoteMetadata) -> Bool)?, date: Date) throws -> StudySession {
    let signpostID = OSSignpostID(log: .studySession)
    os_signpost(.begin, log: .studySession, name: "makeStudySession", signpostID: signpostID)
    var studySession = StudySession()
    for entry in entries {
      guard let metadata = self.metadata[entry.identifier] else {
        assertionFailure()
        continue
      }
      if let due = entry.statistics.due, due > date {
        continue
      }
      if let filter = filter, !filter(entry.identifier, metadata) {
        continue
      }
      studySession.append(
        promptIdentifier: entry.promptIdentifier,
        properties: CardDocumentProperties(documentName: entry.identifier, attributionMarkdown: metadata.preferredTitle)
      )
    }
    os_signpost(.end, log: .studySession, name: "makeStudySession", signpostID: signpostID)
    return studySession
  }

  private nonisolated func asyncProcessValue(scopedKey: ScopedKey, versions: [Version]) {
    Task {
      await processValue(scopedKey: scopedKey, versions: versions)
    }
  }

  private func processValue(scopedKey: ScopedKey, versions: [Version]) {
    let signpostID = OSSignpostID(log: .studySession)
    os_signpost(.begin, log: .studySession, name: "processValue", signpostID: signpostID)
    if scopedKey.key == NoteDatabaseKey.metadata.rawValue {
      self.metadata[scopedKey.scope] = versions.resolved(with: .lastWriterWins)?.bookNoteMetadata
    } else if NoteDatabaseKey(rawValue: scopedKey.key).isPrompt {
      entries.removeAll(where: { $0.promptIdentifier.promptKey == scopedKey.key })
      if let promptInfo = versions.resolved(with: .lastWriterWins)?.promptCollectionInfo {
        for (index, promptStatistics) in promptInfo.promptStatistics.enumerated() {
          let entry = Entry(identifier: scopedKey.scope, promptIdentifier: PromptIdentifier(noteId: scopedKey.scope, promptKey: scopedKey.key, promptIndex: index), statistics: promptStatistics)
          entries.append(entry)
        }
      }
    }
    os_signpost(.end, log: .studySession, name: "processValue", signpostID: signpostID)
  }
}

private extension SessionGenerator {
  struct Entry {
    let identifier: Note.Identifier
    let promptIdentifier: PromptIdentifier
    let statistics: PromptStatistics
  }
}
