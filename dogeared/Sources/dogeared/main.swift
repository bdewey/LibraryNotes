// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import ArgumentParser
import Foundation
import LibraryNotesCore

@main
struct Dogeared: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "dogeared",
    abstract: "Command-line tools for Dogeared Notes databases.",
    subcommands: [
      Export.self,
      Import.self,
      Stats.self,
    ]
  )
}

struct Export: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "export",
    abstract: "Export Dogeared book notes as Markdown files."
  )

  @Argument(help: "Path to a .libnotes database.")
  var databasePath: String

  @Option(name: .shortAndLong, help: "Directory where Markdown files should be written.")
  var output: String

  @Option(name: .customLong("hashtag"), help: "Export notes with this hashtag. May be repeated.")
  var hashtags: [String] = []

  @Option(name: .customLong("year-read"), help: "Export notes read in this year. May be repeated.")
  var yearsRead: [Int] = []

  @Option(name: .customLong("title"), help: "Export notes whose book title contains this query. May be repeated.")
  var titleQueries: [String] = []

  @Option(name: .customLong("author"), help: "Export notes whose author list contains this query. May be repeated.")
  var authorQueries: [String] = []

  @Option(name: .customLong("id"), help: "Export this exact note identifier. May be repeated.")
  var noteIDs: [String] = []

  @Option(name: .customLong("search"), help: "Export notes whose title, authors, tags, or note body contain this query.")
  var searchQuery: String?

  @Flag(help: "Overwrite existing Markdown or asset files.")
  var overwrite = false

  @Flag(name: .customLong("no-assets"), help: "Do not export cover image assets.")
  var noAssets = false

  @Flag(name: .customLong("dry-run"), help: "Print matching note IDs and filenames without writing files.")
  var dryRun = false

  func run() throws {
    let databaseURL = URL(fileURLWithPath: (databasePath as NSString).expandingTildeInPath)
    let outputURL = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
    let database = try NoteDatabase(fileURL: databaseURL, authorDescription: "dogeared", coordinatesFileAccess: false)
    let selection = BookNoteExportSelection(
      hashtags: hashtags,
      yearsRead: yearsRead,
      titleQueries: titleQueries,
      authorQueries: authorQueries,
      noteIDs: noteIDs,
      searchQuery: searchQuery
    )
    let options = BookNoteMarkdownExportOptions(
      includeAssets: !noAssets,
      overwrite: overwrite,
      dryRun: dryRun
    )
    let plan = try BookNoteMarkdownExporter.export(
      from: database,
      to: outputURL,
      selection: selection,
      options: options
    )

    if dryRun {
      for item in plan.items {
        print("\(item.noteIdentifier)\t\(item.markdownURL.lastPathComponent)")
      }
    } else {
      print("Exported \(plan.items.count) notes to \(outputURL.path)")
    }
  }
}

struct Import: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "import",
    abstract: "Import Dogeared book notes from Markdown files with YAML frontmatter."
  )

  @Argument(help: "Path to a .libnotes database.")
  var databasePath: String

  @Argument(help: "Directory containing Markdown files to import.")
  var inputDirectory: String

  @Option(name: .customLong("copy-to"), help: "Copy the database to this path before importing, leaving the original untouched.")
  var copyTo: String?

  @Flag(name: .customLong("overwrite-copy"), help: "Replace the destination passed to --copy-to if it already exists.")
  var overwriteCopy = false

  @Flag(name: .customLong("dry-run"), help: "Print files that would be imported without writing to the database.")
  var dryRun = false

  func run() throws {
    let sourceDatabaseURL = URL(fileURLWithPath: (databasePath as NSString).expandingTildeInPath)
    let databaseURL: URL
    if let copyTo {
      let copyURL = URL(fileURLWithPath: (copyTo as NSString).expandingTildeInPath)
      if FileManager.default.fileExists(atPath: copyURL.path) {
        guard overwriteCopy else {
          throw ValidationError("Copy destination already exists: \(copyURL.path)")
        }
        try FileManager.default.removeItem(at: copyURL)
      }
      try FileManager.default.copyItem(at: sourceDatabaseURL, to: copyURL)
      databaseURL = copyURL
    } else {
      databaseURL = sourceDatabaseURL
    }

    let inputURL = URL(fileURLWithPath: (inputDirectory as NSString).expandingTildeInPath)
    let database = try NoteDatabase(fileURL: databaseURL, authorDescription: "dogeared", coordinatesFileAccess: false)
    let result = try BookNoteMarkdownImporter.import(
      from: inputURL,
      into: database,
      options: BookNoteMarkdownImportOptions(dryRun: dryRun)
    )

    if dryRun {
      for item in result.items {
        print("\(item.markdownURL.lastPathComponent)\t\(item.title)")
      }
    } else {
      print("Imported \(result.items.count) notes into \(databaseURL.path)")
      for item in result.items {
        if let noteIdentifier = item.noteIdentifier {
          print("\(noteIdentifier)\t\(item.markdownURL.lastPathComponent)\t\(item.title)")
        }
      }
    }
  }
}

struct Stats: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stats",
    abstract: "Print basic statistics for a Dogeared Notes database."
  )

  @Argument(help: "Path to a .libnotes database.")
  var databasePath: String

  func run() throws {
    let databaseURL = URL(fileURLWithPath: (databasePath as NSString).expandingTildeInPath)
    let database = try NoteDatabase(fileURL: databaseURL, authorDescription: "dogeared", coordinatesFileAccess: false)
    let noteMetadata = try database.bulkRead { _, key in
      key == NoteDatabaseKey.metadata.rawValue
    }
    let noteCount = Set(noteMetadata.keys.map(\.scope)).count
    print("Notes: \(noteCount)")
  }
}
