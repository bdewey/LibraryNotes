// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import ArgumentParser
import Foundation
import LibraryNotesCore

@main
struct Dogeared: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "dogeared",
    abstract: "Command-line tools for Library Notes databases.",
    subcommands: [
      Stats.self,
    ]
  )
}

struct Stats: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stats",
    abstract: "Print basic statistics for a Library Notes database."
  )

  @Argument(help: "Path to a .libnotes database.")
  var databasePath: String

  func run() throws {
    let databaseURL = URL(fileURLWithPath: (databasePath as NSString).expandingTildeInPath)
    let database = try NoteDatabase(fileURL: databaseURL, authorDescription: "dogeared")
    let noteMetadata = try database.bulkRead { _, key in
      key == NoteDatabaseKey.metadata.rawValue
    }
    let noteCount = Set(noteMetadata.keys.map(\.scope)).count
    print("Notes: \(noteCount)")
  }
}
