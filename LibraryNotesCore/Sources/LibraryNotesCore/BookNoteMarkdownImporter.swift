// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import KeyValueCRDT

public struct BookNoteMarkdownImportOptions: Sendable {
  public init(dryRun: Bool = false) {
    self.dryRun = dryRun
  }

  public var dryRun: Bool
}

public struct BookNoteMarkdownImportItem: Sendable, Equatable {
  public var markdownURL: URL
  public var title: String
  public var authors: [String]
  public var noteIdentifier: Note.Identifier?

  public init(markdownURL: URL, title: String, authors: [String], noteIdentifier: Note.Identifier?) {
    self.markdownURL = markdownURL
    self.title = title
    self.authors = authors
    self.noteIdentifier = noteIdentifier
  }
}

public struct BookNoteMarkdownImportResult: Sendable, Equatable {
  public var items: [BookNoteMarkdownImportItem]

  public init(items: [BookNoteMarkdownImportItem]) {
    self.items = items
  }
}

public struct BookNoteImportPlanningOptions: Sendable {
  public init() {}
}

public struct BookNoteImportExecutionOptions: Sendable {
  public init() {}
}

public struct PlannedBookMetadata: Codable, Sendable, Equatable {
  public var title: String
  public var authors: [String]
  public var yearPublished: Int?
  public var rating: Int?
  public var readingHistory: [String]
  public var catalogIDs: [String: String]

  public init(
    title: String,
    authors: [String],
    yearPublished: Int? = nil,
    rating: Int? = nil,
    readingHistory: [String] = [],
    catalogIDs: [String: String] = [:]
  ) {
    self.title = title
    self.authors = authors
    self.yearPublished = yearPublished
    self.rating = rating
    self.readingHistory = readingHistory
    self.catalogIDs = catalogIDs
  }
}

public enum BookNoteMergeConfidence: String, Codable, Sendable {
  case exactTitleAuthor
  case exactTitle
  case fuzzyTitleAuthor
}

public struct BookNoteMergeCandidate: Codable, Sendable, Equatable {
  public var noteID: Note.Identifier
  public var title: String
  public var authors: [String]
  public var yearPublished: Int?
  public var confidence: BookNoteMergeConfidence
  public var score: Double

  public init(
    noteID: Note.Identifier,
    title: String,
    authors: [String],
    yearPublished: Int?,
    confidence: BookNoteMergeConfidence,
    score: Double
  ) {
    self.noteID = noteID
    self.title = title
    self.authors = authors
    self.yearPublished = yearPublished
    self.confidence = confidence
    self.score = score
  }
}

public enum BookNoteImportAction: Sendable, Equatable {
  case create
  case skip
  case merge(noteID: Note.Identifier)
}

extension BookNoteImportAction: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case noteID
  }

  private enum Kind: String, Codable {
    case create
    case skip
    case merge
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)
    switch kind {
    case .create:
      self = .create
    case .skip:
      self = .skip
    case .merge:
      self = try .merge(noteID: container.decode(Note.Identifier.self, forKey: .noteID))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .create:
      try container.encode(Kind.create, forKey: .kind)
    case .skip:
      try container.encode(Kind.skip, forKey: .kind)
    case .merge(let noteID):
      try container.encode(Kind.merge, forKey: .kind)
      try container.encode(noteID, forKey: .noteID)
    }
  }
}

public struct BookNoteImportPlanItem: Codable, Sendable, Equatable {
  public var sourceFile: String
  public var importedBook: PlannedBookMetadata
  public var candidates: [BookNoteMergeCandidate]
  public var recommendedAction: BookNoteImportAction
  public var action: BookNoteImportAction

  public init(
    sourceFile: String,
    importedBook: PlannedBookMetadata,
    candidates: [BookNoteMergeCandidate],
    recommendedAction: BookNoteImportAction,
    action: BookNoteImportAction
  ) {
    self.sourceFile = sourceFile
    self.importedBook = importedBook
    self.candidates = candidates
    self.recommendedAction = recommendedAction
    self.action = action
  }
}

public struct BookNoteImportPlan: Codable, Sendable, Equatable {
  public var version: Int
  public var createdAt: Date
  public var sourceDirectory: String?
  public var databasePath: String?
  public var items: [BookNoteImportPlanItem]

  public init(
    version: Int = 1,
    createdAt: Date = Date(),
    sourceDirectory: String? = nil,
    databasePath: String? = nil,
    items: [BookNoteImportPlanItem]
  ) {
    self.version = version
    self.createdAt = createdAt
    self.sourceDirectory = sourceDirectory
    self.databasePath = databasePath
    self.items = items
  }
}

public enum BookNoteMarkdownImportError: LocalizedError, Equatable {
  case missingFrontmatter(URL)
  case missingRequiredField(URL, String)
  case invalidField(URL, String)
  case missingSourceFile(String)
  case missingDestinationNote(Note.Identifier)

  public var errorDescription: String? {
    switch self {
    case .missingFrontmatter(let url):
      "Markdown file is missing YAML frontmatter: \(url.path)"
    case .missingRequiredField(let url, let field):
      "Markdown file is missing required frontmatter field '\(field)': \(url.path)"
    case .invalidField(let url, let field):
      "Markdown file has invalid frontmatter field '\(field)': \(url.path)"
    case .missingSourceFile(let sourceFile):
      "Import plan references a missing source file: \(sourceFile)"
    case .missingDestinationNote(let noteIdentifier):
      "Import plan references a missing destination note: \(noteIdentifier)"
    }
  }
}

public enum BookNoteMarkdownImporter {
  @discardableResult
  public static func `import`(
    from inputDirectory: URL,
    into database: NoteDatabase,
    options: BookNoteMarkdownImportOptions = BookNoteMarkdownImportOptions()
  ) throws -> BookNoteMarkdownImportResult {
    let markdownFiles = try markdownFileURLs(in: inputDirectory)
    var items: [BookNoteMarkdownImportItem] = []

    for markdownURL in markdownFiles {
      let parsedNote = try parseNote(at: markdownURL)
      let noteIdentifier = options.dryRun ? nil : try database.createNote(parsedNote.note)
      items.append(BookNoteMarkdownImportItem(
        markdownURL: markdownURL,
        title: parsedNote.book.title,
        authors: parsedNote.book.authors,
        noteIdentifier: noteIdentifier
      ))
    }

    return BookNoteMarkdownImportResult(items: items)
  }

  public static func makePlan(
    from inputDirectory: URL,
    against database: NoteDatabase,
    options: BookNoteImportPlanningOptions = BookNoteImportPlanningOptions()
  ) throws -> BookNoteImportPlan {
    _ = options
    let existingNotes = try existingBookNotes(in: database)
    let markdownFiles = try markdownFileURLs(in: inputDirectory)
    let inputDirectory = inputDirectory.standardizedFileURL
    let items = try markdownFiles.map { markdownURL in
      let parsedNote = try parseImportFile(at: markdownURL)
      let candidates = mergeCandidates(for: parsedNote.book, existingNotes: existingNotes)
      let recommendedAction = recommendedAction(for: candidates)
      return BookNoteImportPlanItem(
        sourceFile: relativePath(from: inputDirectory, to: markdownURL.standardizedFileURL),
        importedBook: PlannedBookMetadata(book: parsedNote.book, catalogIDs: parsedNote.catalogIDs),
        candidates: candidates,
        recommendedAction: recommendedAction,
        action: recommendedAction
      )
    }

    return BookNoteImportPlan(
      sourceDirectory: inputDirectory.path,
      databasePath: database.fileURL.path,
      items: items
    )
  }

  @discardableResult
  public static func execute(
    plan: BookNoteImportPlan,
    from inputDirectory: URL,
    into database: NoteDatabase,
    options: BookNoteImportExecutionOptions = BookNoteImportExecutionOptions()
  ) throws -> BookNoteMarkdownImportResult {
    _ = options
    var items: [BookNoteMarkdownImportItem] = []
    let inputDirectory = inputDirectory.standardizedFileURL

    for planItem in plan.items {
      let markdownURL = inputDirectory.appendingPathComponent(planItem.sourceFile).standardizedFileURL
      guard FileManager.default.fileExists(atPath: markdownURL.path) else {
        throw BookNoteMarkdownImportError.missingSourceFile(planItem.sourceFile)
      }
      let parsedNote = try parseNote(at: markdownURL)
      let noteIdentifier: Note.Identifier?

      switch planItem.action {
      case .create:
        noteIdentifier = try database.createNote(parsedNote.note)
      case .skip:
        noteIdentifier = nil
      case .merge(let destinationNoteID):
        guard (try? database.note(noteIdentifier: destinationNoteID)) != nil else {
          throw BookNoteMarkdownImportError.missingDestinationNote(destinationNoteID)
        }
        try merge(parsedNote.note, sourceFile: planItem.sourceFile, into: destinationNoteID, in: database)
        noteIdentifier = destinationNoteID
      }

      items.append(BookNoteMarkdownImportItem(
        markdownURL: markdownURL,
        title: parsedNote.book.title,
        authors: parsedNote.book.authors,
        noteIdentifier: noteIdentifier
      ))
    }

    return BookNoteMarkdownImportResult(items: items)
  }

  public static func parseNote(at markdownURL: URL) throws -> (note: Note, book: AugmentedBook) {
    let parsed = try parseImportFile(at: markdownURL)
    return (parsed.note, parsed.book)
  }
}

private extension BookNoteMarkdownImporter {
  struct ParsedImportFile {
    var note: Note
    var book: AugmentedBook
    var catalogIDs: [String: String]
    var readingHistory: [String]
  }

  struct ExistingBookNote {
    var noteID: Note.Identifier
    var book: AugmentedBook
  }

  static func parseImportFile(at markdownURL: URL) throws -> ParsedImportFile {
    let contents = try String(contentsOf: markdownURL, encoding: .utf8)
    let document = try FrontmatterDocument(contents: contents, sourceURL: markdownURL)
    let frontmatter = SimpleYAMLMapping.parse(document.frontmatter)
    let book = try book(from: frontmatter, sourceURL: markdownURL)
    let catalogIDs = frontmatter["catalog-ids"]?.mappingValue ?? [:]
    let readingHistory = frontmatter["reading-history"]?.stringArray ?? []

    var note = Note(markdown: document.body)
    let now = Date()
    note.metadata.title = book.title
    note.metadata.creationTimestamp = now
    note.metadata.modifiedTimestamp = now
    note.metadata.book = book
    return ParsedImportFile(note: note, book: book, catalogIDs: catalogIDs, readingHistory: readingHistory)
  }

  static func markdownFileURLs(in inputDirectory: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: inputDirectory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var urls: [URL] = []
    for case let url as URL in enumerator where url.pathExtension.localizedCaseInsensitiveCompare("md") == .orderedSame {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey])
      if values.isRegularFile == true {
        urls.append(url)
      }
    }
    return urls.sorted { $0.path < $1.path }
  }

  static func existingBookNotes(in database: NoteDatabase) throws -> [ExistingBookNote] {
    let metadataRecords = try database.bulkRead { _, key in
      key == NoteDatabaseKey.metadata.rawValue
    }
    return metadataRecords.compactMap { scopedKey, versions in
      guard
        let metadata = versions.resolved(with: .lastWriterWins)?.bookNoteMetadata,
        metadata.folder != PredefinedFolder.recentlyDeleted.rawValue,
        let book = metadata.book
      else {
        return nil
      }
      return ExistingBookNote(noteID: scopedKey.scope, book: book)
    }
  }

  static func mergeCandidates(for importedBook: AugmentedBook, existingNotes: [ExistingBookNote]) -> [BookNoteMergeCandidate] {
    existingNotes.compactMap { existingNote in
      candidate(for: importedBook, existingNote: existingNote)
    }
    .sorted { lhs, rhs in
      if lhs.score != rhs.score {
        return lhs.score > rhs.score
      }
      return lhs.noteID < rhs.noteID
    }
  }

  static func candidate(for importedBook: AugmentedBook, existingNote: ExistingBookNote) -> BookNoteMergeCandidate? {
    let importedTitle = normalizedIdentityString(importedBook.title)
    let existingTitle = normalizedIdentityString(existingNote.book.title)
    guard !importedTitle.isEmpty, !existingTitle.isEmpty else { return nil }

    let importedAuthors = Set(importedBook.authors.map(normalizedIdentityString).filter { !$0.isEmpty })
    let existingAuthors = Set(existingNote.book.authors.map(normalizedIdentityString).filter { !$0.isEmpty })
    let hasOverlappingAuthor = importedAuthors.isEmpty || existingAuthors.isEmpty || !importedAuthors.isDisjoint(with: existingAuthors)

    if importedTitle == existingTitle, hasOverlappingAuthor {
      return BookNoteMergeCandidate(
        noteID: existingNote.noteID,
        title: existingNote.book.title,
        authors: existingNote.book.authors,
        yearPublished: existingNote.book.originalYearPublished ?? existingNote.book.yearPublished,
        confidence: .exactTitleAuthor,
        score: 1
      )
    }

    if importedTitle == existingTitle {
      return BookNoteMergeCandidate(
        noteID: existingNote.noteID,
        title: existingNote.book.title,
        authors: existingNote.book.authors,
        yearPublished: existingNote.book.originalYearPublished ?? existingNote.book.yearPublished,
        confidence: .exactTitle,
        score: 0.88
      )
    }

    let titleScore = stringSimilarity(importedTitle, existingTitle)
    let authorScore = authorSimilarity(importedAuthors, existingAuthors)
    let combinedScore = titleScore * 0.8 + authorScore * 0.2
    guard combinedScore >= 0.82 else { return nil }
    return BookNoteMergeCandidate(
      noteID: existingNote.noteID,
      title: existingNote.book.title,
      authors: existingNote.book.authors,
      yearPublished: existingNote.book.originalYearPublished ?? existingNote.book.yearPublished,
      confidence: .fuzzyTitleAuthor,
      score: combinedScore
    )
  }

  static func recommendedAction(for candidates: [BookNoteMergeCandidate]) -> BookNoteImportAction {
    guard
      candidates.count == 1,
      let candidate = candidates.first,
      candidate.confidence == .exactTitleAuthor
    else {
      return .create
    }
    return .merge(noteID: candidate.noteID)
  }

  static func merge(_ importedNote: Note, sourceFile: String, into destinationNoteID: Note.Identifier, in database: NoteDatabase) throws {
    try database.updateNote(noteIdentifier: destinationNoteID) { existingNote in
      let existingText = existingNote.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let importedText = importedNote.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let mergedText: String = if existingText.isEmpty {
        importedText
      } else if importedText.isEmpty {
        existingText
      } else {
        "\(existingText)\n\n## Imported Notes\n\nSource: \(sourceFile)\n\n\(importedText)"
      }

      var updatedNote = existingNote
      let originalTitle = existingNote.metadata.title
      let originalSummary = existingNote.metadata.summary
      updatedNote.updateMarkdown(mergedText)
      updatedNote.metadata.title = originalTitle.isEmpty ? importedNote.metadata.title : originalTitle
      updatedNote.metadata.summary = originalSummary ?? updatedNote.metadata.summary
      updatedNote.metadata.modifiedTimestamp = Date()
      updatedNote.metadata.book = mergedBook(existingNote.metadata.book, importedBook: importedNote.metadata.book)
      return updatedNote
    }
  }

  static func mergedBook(_ existingBook: AugmentedBook?, importedBook: AugmentedBook?) -> AugmentedBook? {
    guard var existingBook else { return importedBook }
    guard let importedBook else { return existingBook }

    if existingBook.authors.isEmpty {
      existingBook.authors = importedBook.authors
    }
    if existingBook.originalYearPublished == nil {
      existingBook.originalYearPublished = importedBook.originalYearPublished
    }
    if existingBook.yearPublished == nil {
      existingBook.yearPublished = importedBook.yearPublished
    }
    if existingBook.rating == nil {
      existingBook.rating = importedBook.rating
    }
    existingBook.readingHistory = mergedReadingHistory(existingBook.readingHistory, importedReadingHistory: importedBook.readingHistory)
    return existingBook
  }

  static func mergedReadingHistory(_ existingReadingHistory: ReadingHistory?, importedReadingHistory: ReadingHistory?) -> ReadingHistory? {
    guard var existingReadingHistory else { return importedReadingHistory }
    guard let importedEntries = importedReadingHistory?.entries else { return existingReadingHistory }

    var entries = existingReadingHistory.entries ?? []
    let existingKeys = Set(entries.map(readingHistoryKey))
    for importedEntry in importedEntries where !existingKeys.contains(readingHistoryKey(importedEntry)) {
      entries.append(importedEntry)
    }
    existingReadingHistory.entries = entries
    existingReadingHistory.hasRead = existingReadingHistory.hasRead || importedReadingHistory?.hasRead == true || entries.contains { $0.finish != nil }
    existingReadingHistory.multipleReadings = existingReadingHistory.multipleReadings || entries.count > 1
    return existingReadingHistory
  }

  static func readingHistoryKey(_ entry: ReadingHistory.Entry) -> String {
    [
      entry.start?.yamlDate ?? "",
      entry.finish?.yamlDate ?? "",
    ].joined(separator: "|")
  }

  static func book(from frontmatter: [String: SimpleYAMLValue], sourceURL: URL) throws -> AugmentedBook {
    guard let title = frontmatter["title"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
      throw BookNoteMarkdownImportError.missingRequiredField(sourceURL, "title")
    }
    guard let authors = frontmatter["authors"]?.stringArray else {
      throw BookNoteMarkdownImportError.missingRequiredField(sourceURL, "authors")
    }

    var book = Book(
      title: title,
      authors: authors,
      yearPublished: nil,
      originalYearPublished: frontmatter["year-published"]?.intValue
    )
    if frontmatter.keys.contains("year-published"), book.originalYearPublished == nil {
      throw BookNoteMarkdownImportError.invalidField(sourceURL, "year-published")
    }
    if let tags = frontmatter["tags"]?.stringArray {
      book.tags = tags
    }

    var augmentedBook = AugmentedBook(book: book, rating: frontmatter["rating"]?.intValue)
    if frontmatter.keys.contains("rating"), augmentedBook.rating == nil {
      throw BookNoteMarkdownImportError.invalidField(sourceURL, "rating")
    }
    if let readingHistory = try readingHistory(from: frontmatter["reading-history"], sourceURL: sourceURL) {
      augmentedBook.readingHistory = readingHistory
    }
    return augmentedBook
  }

  static func readingHistory(from value: SimpleYAMLValue?, sourceURL: URL) throws -> ReadingHistory? {
    guard let value else { return nil }
    guard let dateStrings = value.stringArray else {
      throw BookNoteMarkdownImportError.invalidField(sourceURL, "reading-history")
    }
    var readingHistory = ReadingHistory()
    for dateString in dateStrings {
      guard let components = DateComponents(yamlDate: dateString) else {
        throw BookNoteMarkdownImportError.invalidField(sourceURL, "reading-history")
      }
      readingHistory.finishReading(finishDate: components)
    }
    return readingHistory
  }

  static func relativePath(from directory: URL, to file: URL) -> String {
    let directoryComponents = directory.standardizedFileURL.pathComponents
    let fileComponents = file.standardizedFileURL.pathComponents
    let sharedCount = zip(directoryComponents, fileComponents).prefix { $0 == $1 }.count
    let relativeComponents = fileComponents.dropFirst(sharedCount)
    return relativeComponents.joined(separator: "/")
  }

  static func normalizedIdentityString(_ value: String) -> String {
    value
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  static func authorSimilarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
    if lhs.isEmpty || rhs.isEmpty {
      return 0.5
    }
    if !lhs.isDisjoint(with: rhs) {
      return 1
    }
    let bestScore = lhs.flatMap { lhsAuthor in
      rhs.map { rhsAuthor in stringSimilarity(lhsAuthor, rhsAuthor) }
    }.max() ?? 0
    return bestScore
  }

  static func stringSimilarity(_ lhs: String, _ rhs: String) -> Double {
    guard !lhs.isEmpty || !rhs.isEmpty else { return 1 }
    guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
    let distance = levenshteinDistance(lhs, rhs)
    return 1 - Double(distance) / Double(max(lhs.count, rhs.count))
  }

  static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
    let lhs = Array(lhs)
    let rhs = Array(rhs)
    var previous = Array(0 ... rhs.count)
    var current = Array(repeating: 0, count: rhs.count + 1)

    for lhsIndex in 1 ... lhs.count {
      current[0] = lhsIndex
      for rhsIndex in 1 ... rhs.count {
        if lhs[lhsIndex - 1] == rhs[rhsIndex - 1] {
          current[rhsIndex] = previous[rhsIndex - 1]
        } else {
          current[rhsIndex] = min(previous[rhsIndex], current[rhsIndex - 1], previous[rhsIndex - 1]) + 1
        }
      }
      previous = current
    }
    return previous[rhs.count]
  }
}

private extension PlannedBookMetadata {
  init(book: AugmentedBook, catalogIDs: [String: String]) {
    self.init(
      title: book.title,
      authors: book.authors,
      yearPublished: book.originalYearPublished ?? book.yearPublished,
      rating: book.rating,
      readingHistory: book.readingHistory?.entries?.compactMap(\.finish?.yamlDate) ?? [],
      catalogIDs: catalogIDs
    )
  }
}

private struct FrontmatterDocument {
  var frontmatter: String
  var body: String

  init(contents: String, sourceURL: URL) throws {
    let normalized = contents.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
      throw BookNoteMarkdownImportError.missingFrontmatter(sourceURL)
    }
    guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
      throw BookNoteMarkdownImportError.missingFrontmatter(sourceURL)
    }

    self.frontmatter = lines[1 ..< closingIndex].joined(separator: "\n")
    var bodyStartIndex = lines.index(after: closingIndex)
    if bodyStartIndex < lines.endIndex, lines[bodyStartIndex].isEmpty {
      bodyStartIndex = lines.index(after: bodyStartIndex)
    }
    self.body = bodyStartIndex < lines.endIndex ? lines[bodyStartIndex...].joined(separator: "\n") : ""
  }
}

private enum SimpleYAMLValue: Equatable {
  case scalar(String)
  case sequence([String])
  case mapping([String: String])

  var stringValue: String? {
    switch self {
    case .scalar(let value):
      value
    case .sequence, .mapping:
      nil
    }
  }

  var stringArray: [String]? {
    switch self {
    case .sequence(let values):
      return values
    case .scalar(let value) where value == "[]":
      return []
    case .scalar, .mapping:
      return nil
    }
  }

  var intValue: Int? {
    guard let stringValue else { return nil }
    return Int(stringValue)
  }

  var mappingValue: [String: String]? {
    switch self {
    case .mapping(let value):
      value
    case .scalar, .sequence:
      nil
    }
  }
}

private enum SimpleYAMLMapping {
  static func parse(_ yaml: String) -> [String: SimpleYAMLValue] {
    let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var result: [String: SimpleYAMLValue] = [:]
    var index = lines.startIndex

    while index < lines.endIndex {
      let rawLine = lines[index]
      let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
      index = lines.index(after: index)
      guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#"), rawLine.first?.isWhitespace != true else {
        continue
      }

      guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
        continue
      }
      let key = String(trimmedLine[..<colonIndex])
      let valuePart = trimmedLine[trimmedLine.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
      if !valuePart.isEmpty {
        result[key] = .scalar(parseScalar(valuePart))
        continue
      }

      var sequence: [String] = []
      var mapping: [String: String] = [:]
      while index < lines.endIndex {
        let childLine = lines[index]
        let childTrimmed = childLine.trimmingCharacters(in: .whitespaces)
        guard childLine.first?.isWhitespace == true, !childTrimmed.isEmpty else {
          if childTrimmed.isEmpty {
            index = lines.index(after: index)
            continue
          }
          break
        }
        index = lines.index(after: index)
        if childTrimmed.hasPrefix("-") {
          let valueStart = childTrimmed.index(after: childTrimmed.startIndex)
          let value = childTrimmed[valueStart...].trimmingCharacters(in: .whitespaces)
          sequence.append(parseScalar(value))
        } else if let childColon = childTrimmed.firstIndex(of: ":") {
          let childKey = String(childTrimmed[..<childColon])
          let childValue = childTrimmed[childTrimmed.index(after: childColon)...].trimmingCharacters(in: .whitespaces)
          mapping[childKey] = parseScalar(childValue)
        }
      }

      if !sequence.isEmpty {
        result[key] = .sequence(sequence)
      } else if !mapping.isEmpty {
        result[key] = .mapping(mapping)
      } else {
        result[key] = .sequence([])
      }
    }

    return result
  }

  private static func parseScalar(_ value: String) -> String {
    if value == "[]" {
      return value
    }
    if value.hasPrefix("\""), value.hasSuffix("\""), let data = value.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) {
      return decoded
    }
    return value
  }
}

private extension DateComponents {
  var yamlDate: String? {
    guard let year else {
      return nil
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

  init?(yamlDate: String) {
    let components = yamlDate.split(separator: "-", omittingEmptySubsequences: false)
    guard (1 ... 3).contains(components.count), let year = Int(components[0]), components[0].count == 4 else {
      return nil
    }
    self.init()
    self.year = year

    if components.count >= 2 {
      guard let month = Int(components[1]), (1 ... 12).contains(month), components[1].count == 2 else {
        return nil
      }
      self.month = month
    }
    if components.count == 3 {
      guard let day = Int(components[2]), (1 ... 31).contains(day), components[2].count == 2 else {
        return nil
      }
      self.day = day
    }
  }
}
