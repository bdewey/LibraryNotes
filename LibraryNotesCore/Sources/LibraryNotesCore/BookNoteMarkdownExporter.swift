// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import KeyValueCRDT
import UniformTypeIdentifiers

public struct BookNoteExportSelection: Sendable {
  public init(
    hashtags: [String] = [],
    yearsRead: [Int] = [],
    titleQueries: [String] = [],
    authorQueries: [String] = [],
    noteIDs: [Note.Identifier] = [],
    searchQuery: String? = nil
  ) {
    self.hashtags = hashtags.map(Self.normalizedHashtag)
    self.yearsRead = yearsRead
    self.titleQueries = titleQueries
    self.authorQueries = authorQueries
    self.noteIDs = noteIDs
    self.searchQuery = searchQuery
  }

  public var hashtags: [String]
  public var yearsRead: [Int]
  public var titleQueries: [String]
  public var authorQueries: [String]
  public var noteIDs: [Note.Identifier]
  public var searchQuery: String?

  public var isEmpty: Bool {
    hashtags.isEmpty &&
      yearsRead.isEmpty &&
      titleQueries.isEmpty &&
      authorQueries.isEmpty &&
      noteIDs.isEmpty &&
      (searchQuery?.isEmpty ?? true)
  }

  private static func normalizedHashtag(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return trimmed }
    return "#\(trimmed)"
  }
}

public struct BookNoteMarkdownExportOptions: Sendable {
  public init(includeAssets: Bool = true, overwrite: Bool = false, dryRun: Bool = false) {
    self.includeAssets = includeAssets
    self.overwrite = overwrite
    self.dryRun = dryRun
  }

  public var includeAssets: Bool
  public var overwrite: Bool
  public var dryRun: Bool
}

public struct BookNoteMarkdownExportItem: Sendable, Equatable {
  public var noteIdentifier: Note.Identifier
  public var markdownURL: URL
  public var assetURL: URL?

  public init(noteIdentifier: Note.Identifier, markdownURL: URL, assetURL: URL?) {
    self.noteIdentifier = noteIdentifier
    self.markdownURL = markdownURL
    self.assetURL = assetURL
  }
}

public struct BookNoteMarkdownExportPlan: Sendable, Equatable {
  public var items: [BookNoteMarkdownExportItem]

  public init(items: [BookNoteMarkdownExportItem]) {
    self.items = items
  }
}

public enum BookNoteMarkdownExportError: LocalizedError, Equatable {
  case outputCollision(URL)

  public var errorDescription: String? {
    switch self {
    case .outputCollision(let url):
      "Export output already exists: \(url.path)"
    }
  }
}

public enum BookNoteMarkdownExporter {
  public static func frontmatter(for book: AugmentedBook) -> String {
    var buffer = "---\n"
    buffer.append("title: \(yamlString(book.title))\n")
    buffer.append("authors:\n")
    for author in book.authors {
      buffer.append("- \(yamlString(author))\n")
    }
    if let year = book.originalYearPublished ?? book.yearPublished {
      buffer.append("year-published: \(year)\n")
    }
    if let rating = book.rating {
      buffer.append("rating: \(rating)\n")
    }
    if let readingHistoryEntries = book.readingHistory?.entries?.filter({ $0.finish != nil }), !readingHistoryEntries.isEmpty {
      buffer.append("reading-history:\n")
      for entry in readingHistoryEntries {
        buffer.append("- \(entry.finish!.yaml)\n")
      }
    }
    buffer.append("---\n\n")
    return buffer
  }

  public static func yamlString(_ value: String) -> String {
    guard
      let data = try? JSONEncoder().encode(value),
      let encoded = String(data: data, encoding: .utf8)
    else {
      assertionFailure("String values should always encode as JSON")
      return "\"\""
    }
    return encoded
  }

  public static func plan(
    from database: NoteDatabase,
    to outputDirectory: URL,
    selection: BookNoteExportSelection = BookNoteExportSelection(),
    options: BookNoteMarkdownExportOptions = BookNoteMarkdownExportOptions()
  ) throws -> BookNoteMarkdownExportPlan {
    let candidates = try candidateNotes(from: database, selection: selection)
    var usedFilenames = Set<String>()
    var items: [BookNoteMarkdownExportItem] = []

    for candidate in candidates {
      let filename = uniqueFilename(for: candidate.metadata.exportTitle, usedFilenames: &usedFilenames)
      let markdownURL = outputDirectory.appendingPathComponent(filename)
      var assetURL: URL?
      if options.includeAssets, let coverImage = try coverImage(from: database, noteIdentifier: candidate.identifier) {
        let assetDirectory = markdownURL.deletingPathExtension()
        var imageURL = assetDirectory.appendingPathComponent("coverImage")
        if let type = UTType(mimeType: coverImage.mimeType), let pathExtension = type.preferredFilenameExtension {
          imageURL.appendPathExtension(pathExtension)
        }
        assetURL = imageURL
      }
      items.append(BookNoteMarkdownExportItem(noteIdentifier: candidate.identifier, markdownURL: markdownURL, assetURL: assetURL))
    }
    return BookNoteMarkdownExportPlan(items: items)
  }

  @discardableResult
  public static func export(
    from database: NoteDatabase,
    to outputDirectory: URL,
    selection: BookNoteExportSelection = BookNoteExportSelection(),
    options: BookNoteMarkdownExportOptions = BookNoteMarkdownExportOptions()
  ) throws -> BookNoteMarkdownExportPlan {
    let candidates = try candidateNotes(from: database, selection: selection)
    var usedFilenames = Set<String>()
    var plannedItems: [BookNoteMarkdownExportItem] = []
    var writes: [(candidate: CandidateNote, markdownURL: URL, coverImage: CoverImage?)] = []

    for candidate in candidates {
      let filename = uniqueFilename(for: candidate.metadata.exportTitle, usedFilenames: &usedFilenames)
      let markdownURL = outputDirectory.appendingPathComponent(filename)
      let coverImage = options.includeAssets ? try coverImage(from: database, noteIdentifier: candidate.identifier) : nil
      let assetURL = coverImage.map { coverImage in
        let assetDirectory = markdownURL.deletingPathExtension()
        var imageURL = assetDirectory.appendingPathComponent("coverImage")
        if let type = UTType(mimeType: coverImage.mimeType), let pathExtension = type.preferredFilenameExtension {
          imageURL.appendPathExtension(pathExtension)
        }
        return imageURL
      }
      plannedItems.append(BookNoteMarkdownExportItem(noteIdentifier: candidate.identifier, markdownURL: markdownURL, assetURL: assetURL))
      writes.append((candidate: candidate, markdownURL: markdownURL, coverImage: coverImage))
    }

    let plan = BookNoteMarkdownExportPlan(items: plannedItems)
    guard !options.dryRun else { return plan }

    if !options.overwrite {
      for item in plan.items {
        if FileManager.default.fileExists(atPath: item.markdownURL.path) {
          throw BookNoteMarkdownExportError.outputCollision(item.markdownURL)
        }
        if let assetURL = item.assetURL, FileManager.default.fileExists(atPath: assetURL.path) {
          throw BookNoteMarkdownExportError.outputCollision(assetURL)
        }
      }
    }

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    for write in writes {
      var buffer = frontmatter(for: write.candidate.book)
      if let coverImage = write.coverImage {
        let imageDirectory = write.markdownURL.deletingPathExtension()
        var imageURL = imageDirectory.appendingPathComponent("coverImage")
        if let type = UTType(mimeType: coverImage.mimeType), let pathExtension = type.preferredFilenameExtension {
          imageURL.appendPathExtension(pathExtension)
        }
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try coverImage.data.write(to: imageURL, options: .atomic)
        buffer.append("![Book cover](\(imageDirectory.lastPathComponent)/\(imageURL.lastPathComponent))\n\n")
      }
      if let text = write.candidate.text {
        text.write(to: &buffer)
      }
      try buffer.write(to: write.markdownURL, atomically: true, encoding: .utf8)
    }
    return plan
  }
}

private extension BookNoteMarkdownExporter {
  struct CandidateNote {
    var identifier: Note.Identifier
    var metadata: BookNoteMetadata
    var text: String?
    var book: AugmentedBook
  }

  struct CoverImage {
    var mimeType: String
    var data: Data
  }

  static func candidateNotes(from database: NoteDatabase, selection: BookNoteExportSelection) throws -> [CandidateNote] {
    let records = try database.bulkRead { _, key in
      key == NoteDatabaseKey.metadata.rawValue || key == NoteDatabaseKey.noteText.rawValue
    }

    var candidates: [CandidateNote] = []
    for (scopedKey, versions) in records where scopedKey.key == NoteDatabaseKey.metadata.rawValue {
      guard
        let metadata = versions.resolved(with: .lastWriterWins)?.bookNoteMetadata,
        metadata.folder != PredefinedFolder.recentlyDeleted.rawValue,
        let book = metadata.book
      else {
        continue
      }
      let text = records[ScopedKey(scope: scopedKey.scope, key: NoteDatabaseKey.noteText.rawValue)]?
        .resolved(with: .lastWriterWins)?
        .text
      guard matches(metadata: metadata, text: text, identifier: scopedKey.scope, book: book, selection: selection) else {
        continue
      }
      candidates.append(CandidateNote(identifier: scopedKey.scope, metadata: metadata, text: text, book: book))
    }

    return candidates.sorted { lhs, rhs in
      let lhsSortKey = sortKey(for: lhs)
      let rhsSortKey = sortKey(for: rhs)
      return lexicographicallyPrecedes(lhsSortKey, rhsSortKey)
    }
  }

  static func matches(metadata: BookNoteMetadata, text: String?, identifier: Note.Identifier, book: AugmentedBook, selection: BookNoteExportSelection) -> Bool {
    if !selection.noteIDs.isEmpty, !selection.noteIDs.contains(identifier) {
      return false
    }

    if !selection.hashtags.isEmpty {
      let noteTags = Set(metadata.tags + (book.tags ?? []))
      if !selection.hashtags.contains(where: { noteTags.contains($0) }) {
        return false
      }
    }

    if !selection.yearsRead.isEmpty {
      let yearsRead = Set(book.readingHistory?.entries?.compactMap { $0.finish?.year } ?? [])
      if !selection.yearsRead.contains(where: { yearsRead.contains($0) }) {
        return false
      }
    }

    if !selection.titleQueries.isEmpty, !selection.titleQueries.contains(where: { book.title.localizedCaseInsensitiveContains($0) }) {
      return false
    }

    if !selection.authorQueries.isEmpty {
      let authors = book.authors.joined(separator: "\n")
      if !selection.authorQueries.contains(where: { authors.localizedCaseInsensitiveContains($0) }) {
        return false
      }
    }

    if let searchQuery = selection.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !searchQuery.isEmpty {
      let searchableText = [
        book.title,
        book.authors.joined(separator: " "),
        metadata.tags.joined(separator: " "),
        book.tags?.joined(separator: " "),
        text,
      ]
      .compactMap { $0 }
      .joined(separator: "\n")
      if !searchableText.localizedCaseInsensitiveContains(searchQuery) {
        return false
      }
    }

    return true
  }

  static func sortKey(for candidate: CandidateNote) -> [String] {
    [
      candidate.book.title.lowercased(),
      candidate.book.authors.first?.lowercased() ?? "",
      candidate.identifier,
    ]
  }

  static func lexicographicallyPrecedes(_ lhs: [String], _ rhs: [String]) -> Bool {
    for (lhsValue, rhsValue) in zip(lhs, rhs) {
      if lhsValue == rhsValue { continue }
      return lhsValue < rhsValue
    }
    return lhs.count < rhs.count
  }

  static func uniqueFilename(for title: String, usedFilenames: inout Set<String>) -> String {
    let sanitizedName = (title.isEmpty ? "untitled" : title)
      .lowercased()
      .whitespaceCondensed()
      .sanitized()
    var filename = "\(sanitizedName).md"
    var uniquifier = 0
    while usedFilenames.contains(filename) {
      uniquifier += 1
      filename = "\(sanitizedName)-\(uniquifier).md"
    }
    usedFilenames.insert(filename)
    return filename
  }

  static func coverImage(from database: NoteDatabase, noteIdentifier: Note.Identifier) throws -> CoverImage? {
    guard let coverImage = try database.read(noteIdentifier: noteIdentifier, key: .coverImage).resolved(with: .lastWriterWins) else {
      return nil
    }
    switch coverImage {
    case .blob(mimeType: let mimeType, blob: let data):
      return CoverImage(mimeType: mimeType, data: data)
    case .json, .null, .text:
      return nil
    }
  }
}

private extension BookNoteMetadata {
  var exportTitle: String {
    if let book {
      "\(book.title) \(book.authors.joined(separator: " "))"
    } else {
      title
    }
  }
}

private extension DateComponents {
  var yaml: String {
    guard let year else {
      return ""
    }
    var output = "\(year)"
    guard let month else {
      return output
    }
    output.append("-\(month.formatted(.number.precision(.integerLength(2))))")
    guard let day else {
      return output
    }
    output.append("-\(day.formatted(.number.precision(.integerLength(2))))")
    return output
  }
}
