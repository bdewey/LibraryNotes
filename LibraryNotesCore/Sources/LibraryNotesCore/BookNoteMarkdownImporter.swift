// Copyright (c) 2026 Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation

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

public enum BookNoteMarkdownImportError: LocalizedError, Equatable {
  case missingFrontmatter(URL)
  case missingRequiredField(URL, String)
  case invalidField(URL, String)

  public var errorDescription: String? {
    switch self {
    case .missingFrontmatter(let url):
      "Markdown file is missing YAML frontmatter: \(url.path)"
    case .missingRequiredField(let url, let field):
      "Markdown file is missing required frontmatter field '\(field)': \(url.path)"
    case .invalidField(let url, let field):
      "Markdown file has invalid frontmatter field '\(field)': \(url.path)"
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

  public static func parseNote(at markdownURL: URL) throws -> (note: Note, book: AugmentedBook) {
    let contents = try String(contentsOf: markdownURL, encoding: .utf8)
    let document = try FrontmatterDocument(contents: contents, sourceURL: markdownURL)
    let frontmatter = SimpleYAMLMapping.parse(document.frontmatter)
    let book = try book(from: frontmatter, sourceURL: markdownURL)

    var note = Note(markdown: document.body)
    let now = Date()
    note.metadata.title = book.title
    note.metadata.creationTimestamp = now
    note.metadata.modifiedTimestamp = now
    note.metadata.book = book
    return (note, book)
  }
}

private extension BookNoteMarkdownImporter {
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

    frontmatter = lines[1..<closingIndex].joined(separator: "\n")
    var bodyStartIndex = lines.index(after: closingIndex)
    if bodyStartIndex < lines.endIndex, lines[bodyStartIndex].isEmpty {
      bodyStartIndex = lines.index(after: bodyStartIndex)
    }
    body = bodyStartIndex < lines.endIndex ? lines[bodyStartIndex...].joined(separator: "\n") : ""
  }
}

private enum SimpleYAMLValue: Equatable {
  case scalar(String)
  case sequence([String])
  case mapping([String: String])

  var stringValue: String? {
    switch self {
    case .scalar(let value):
      return value
    case .sequence, .mapping:
      return nil
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
  init?(yamlDate: String) {
    let components = yamlDate.split(separator: "-", omittingEmptySubsequences: false)
    guard (1...3).contains(components.count), let year = Int(components[0]), components[0].count == 4 else {
      return nil
    }
    self.init()
    self.year = year

    if components.count >= 2 {
      guard let month = Int(components[1]), (1...12).contains(month), components[1].count == 2 else {
        return nil
      }
      self.month = month
    }
    if components.count == 3 {
      guard let day = Int(components[2]), (1...31).contains(day), components[2].count == 2 else {
        return nil
      }
      self.day = day
    }
  }
}
