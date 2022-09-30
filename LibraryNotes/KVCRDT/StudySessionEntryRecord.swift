// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// The result of a database query for eligible prompts.
struct StudySessionEntryRecord: FetchableRecord, Codable {
  /// The note identifier holding the prompt.
  var scope: Note.Identifier

  /// The prompt collection key.
  var key: String

  /// The index in the prompt collection.
  var promptIndex: Int

  // TODO: Get rid of this.
  /// The title of the note associated with the prompt.
  var title: String?

  /// The prompt's due date.
  var due: Date?

  /// The `PromptIdentifier` associated with this prompt.
  var promptIdentifier: PromptIdentifier {
    PromptIdentifier(noteId: scope, promptKey: key, promptIndex: promptIndex)
  }

  /// SQL to select valid prompts.
  /// - parameter identifiers: If set, will limit results to prompts that come from these notes.
  /// - parameter due: Prompts scheduled after `due` will not be included in the results.
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
    if let identifiers {
      baseSQL += " AND entry.scope IN \(identifiers)"
    }
    return baseSQL + " ORDER BY due"
  }
}
