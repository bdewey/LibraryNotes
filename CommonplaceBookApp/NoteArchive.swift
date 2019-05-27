// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import MiniMarkdown
import Yams

public struct NoteArchiveVersion: LosslessStringConvertible {
  public let timestamp: Date
  public let digest: String

  public init(timestamp: Date, digest: String) {
    self.timestamp = timestamp
    self.digest = digest
  }

  public init?(_ description: String) {
    let components = description.split(separator: " ").map(String.init)
    guard
      components.count == 2,
      let date = ISO8601DateFormatter().date(from: components[0]) else { return nil }

    self.timestamp = date
    self.digest = components[1]
  }

  public var description: String {
    let date = ISO8601DateFormatter().string(from: timestamp)
    return [date, digest].joined(separator: " ")
  }
}

public struct NoteArchive {
  /// Default initializer; creates an empty NoteBundle.
  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  /// Deserialize an archive.
  public init(parsingRules: ParsingRules, textSerialization: String) throws {
    self.parsingRules = parsingRules
    self.archive = try TextSnippetArchive(textSerialization: textSerialization)
    self.pagePropertiesVersionHistory = try NoteArchive.getVersionHistory(from: archive)
    if let identifier = pagePropertiesVersionHistory.last?.digest {
      self.pagePropertyDigests = try NoteArchive.getPageManifest(
        from: archive,
        manifestIdentifier: identifier
      )
    } else {
      self.pagePropertyDigests = [:]
    }
  }

  /// Rules used to parse challenge templates.
  public let parsingRules: ParsingRules

  private var archive = TextSnippetArchive()

  private var pagePropertiesVersionHistory: [NoteArchiveVersion] = []

  /// Mapping of page UUID (constant across revisions) to the current page properties digest
  private var pagePropertyDigests: [String: String] = [:]

  /// Returns the current mapping of page id to page properties
  public var pageProperties: [String: PageProperties] {
    return pagePropertyDigests.compactMapValues({ propertyDigest -> PageProperties? in
      guard
        let snippet = archive.snippetDigestIndex[propertyDigest],
        let properties = try? PageProperties(snippet) else {
          return nil
      }
      return properties
    })
  }

  public enum SerializationError: Error {
    case noVersionReference
  }

  public enum RetrievalError: Error {
    case noSuchPage(String)
    case noSuchText(String)
  }

  /// Timestamps of all of the versions stored in this archive.
  public var versions: [Date] {
    return pagePropertiesVersionHistory.map { $0.timestamp }
  }

  /// Our file import dates
  public var fileImportDates: [String: Date] {
    do {
      let records = try getFileImportRecords()
      return records.mapValues { $0.changeDate }
    } catch {
      DDLogError("Unexpected error getting file import records: \(error)")
      return [:]
    }
  }

  /// Text version of the archive, suitable for storing to disk.
  public func textSerialized() -> String {
    return archive.textSerialized()
  }

  /// Creates a new page with the given text.
  /// - returns: An identifier that can be used to return the current version of this page
  ///            at any point in time.
  @discardableResult
  mutating public func insertNote(_ text: String, timestamp: Date) throws -> String {
    let (propertiesSnippet, _) = try archivePageProperties(from: text, timestamp: timestamp)
    let key = UUID().uuidString
    pagePropertyDigests[key] = propertiesSnippet.sha1Digest
    try archivePageManifestVersion(timestamp: timestamp)
    return key
  }

  /// Gets the current version of the text for a particular page.
  public func currentText(for pageIdentifier: String) throws -> String {
    let properties = try currentPageProperties(for: pageIdentifier).properties
    guard let noteSnippet = archive.snippetDigestIndex[properties.sha1Digest] else {
      throw RetrievalError.noSuchText(properties.sha1Digest)
    }
    return noteSnippet.text
  }

  private func currentPageProperties(
    for pageIdentifier: String
  ) throws -> (snippet: TextSnippet, properties: PageProperties) {
    guard let propertiesDigest = pagePropertyDigests[pageIdentifier],
      let propertiesSnippet = archive.snippetDigestIndex[propertiesDigest] else {
        throw RetrievalError.noSuchPage(pageIdentifier)
    }
    return (propertiesSnippet, try PageProperties(propertiesSnippet))
  }

  /// Updates the text associated with `pageIdentifier` to `text`, creating a new version
  /// in the process.
  ///
  /// - note: If `text` is not different from the current value associated with `pageIdentifier`,
  ///         this operation is a no-op. No new version gets created.
  public mutating func updateText(
    for pageIdentifier: String,
    to text: String,
    at timestamp: Date
  ) throws {
    let (existingSnippet, existingProperties) = try currentPageProperties(for: pageIdentifier)
    let (newSnippet, newProperties) = try archivePageProperties(from: text, timestamp: timestamp)
    // New content is the same as the old content
    if newProperties.sha1Digest == existingProperties.sha1Digest {
      return
    }
    existingSnippet.encodeAsDiff(from: newSnippet)
    guard let existingTextSnippet = archive.snippetDigestIndex[existingProperties.sha1Digest] else {
      throw RetrievalError.noSuchPage(existingProperties.sha1Digest)
    }
    guard let newTextSnippet = archive.snippetDigestIndex[newProperties.sha1Digest] else {
      throw RetrievalError.noSuchPage(newProperties.sha1Digest)
    }
    existingTextSnippet.encodeAsDiff(from: newTextSnippet)
    pagePropertyDigests[pageIdentifier] = newSnippet.sha1Digest
    try archivePageManifestVersion(timestamp: timestamp)
  }

  private mutating func archivePageManifestVersion(timestamp: Date) throws {
    let version = NoteArchiveVersion(timestamp: timestamp, digest: archivePageManifest())
    if let existingVersion = pagePropertiesVersionHistory.last,
      let oldManifestSnippet = archive.snippetDigestIndex[existingVersion.digest],
      let newManifestSnippet = archive.snippetDigestIndex[version.digest] {
      oldManifestSnippet.encodeAsDiff(from: newManifestSnippet)
    }
    pagePropertiesVersionHistory.append(version)
    try archiveVersionHistory()
  }

  private mutating func archiveVersionHistory() throws {
    let history = pagePropertiesVersionHistory.map { $0.description }.joined(separator: "\n")
    if let existingHistory = archive.symbolicReferences["versions"] {
      archive.removeSnippet(withDigest: existingHistory)
    }
    let historySnippet = archive.insert(history)
    try archive.insertSymbolicReference(key: "versions", value: historySnippet.sha1Digest)
  }

  private static func getVersionHistory(
    from archive: TextSnippetArchive
  ) throws -> [NoteArchiveVersion] {
    guard
      let versionDigest = archive.symbolicReferences["versions"],
      let versionSnippet = archive.snippetDigestIndex[versionDigest] else {
      throw SerializationError.noVersionReference
    }
    return versionSnippet.text.split(separator: "\n")
      .map(String.init)
      .compactMap(NoteArchiveVersion.init)
  }

  private mutating func archivePageManifest() -> String {
    let manifest = pagePropertyDigests
      .map({ "\($0.key) \($0.value)" })
      .sorted()
      .joined(separator: "\n")
    let manifestSnippet = archive.insert(manifest)
    return manifestSnippet.sha1Digest
  }

  private static func getPageManifest(
    from archive: TextSnippetArchive,
    manifestIdentifier: String
  ) throws -> [String: String] {
    guard let manifestSnippet = archive.snippetDigestIndex[manifestIdentifier] else {
      throw RetrievalError.noSuchPage(manifestIdentifier)
    }
    let keyValuePairs = manifestSnippet.text
      .split(separator: "\n")
      .compactMap { line -> (String, String)? in
        let components = line.split(separator: " ")
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
      }
    return Dictionary(uniqueKeysWithValues: keyValuePairs)
  }

  /// Synchronously extract properties & challenge templates from the contents of a file.
  mutating func archivePageProperties(
    from text: String,
    timestamp: Date
  ) throws -> (snippet: TextSnippet, properties: PageProperties) {
    let textSnippet = archive.insert(text)
    let nodes = parsingRules.parse(text)
    let challengeTemplateKeys = nodes.archiveChallengeTemplates(to: &archive)
    let properties = PageProperties(
      sha1Digest: textSnippet.sha1Digest,
      timestamp: timestamp,
      hashtags: nodes.hashtags,
      title: String(nodes.title.split(separator: "\n").first ?? ""),
      cardTemplates: challengeTemplateKeys.map { $0.description }
    )
    let propertiesSnippet = try properties.makeSnippet()
    archive.insert(propertiesSnippet)
    return (propertiesSnippet, properties)
  }
}

public extension NoteArchive {
  mutating func importFile(
    named fileName: String,
    text: String,
    contentChangeDate: Date,
    importDate: Date
  ) throws {
    var importRecords = try getFileImportRecords()
    if let importRecord = importRecords[fileName] {
      if !contentChangeDate.closeEnough(to: importRecord.changeDate) {
        try updateText(for: importRecord.pageIdentifier, to: text, at: importDate)
      }
    } else {
      let pageIdentifier = try insertNote(text, timestamp: importDate)
      importRecords[fileName] = FileImportRecord(
        pageIdentifier: pageIdentifier,
        changeDate: contentChangeDate
      )
      try archiveFileImportRecords(importRecords)
    }
  }
}

private extension NoteArchive {
  struct FileImportRecord: Codable {
    let pageIdentifier: String
    let changeDate: Date
  }

  func getFileImportRecords() throws -> [String: FileImportRecord] {
    guard
      let snippetIdentifier = archive.symbolicReferences["file-import"],
      let snippet = archive.snippetDigestIndex[snippetIdentifier] else {
        return [:]
    }
    return try YAMLDecoder().decode([String: FileImportRecord].self, from: snippet.text)
  }

  mutating func archiveFileImportRecords(_ records: [String: FileImportRecord]) throws {
    let encoded = try YAMLEncoder().encode(records)
    let snippet = TextSnippet(encoded)
    if let exisitingSnippetIdentifier = archive.symbolicReferences["file-import"] {
      archive.removeSnippet(withDigest: exisitingSnippetIdentifier)
    }
    archive.insert(snippet)
    try archive.insertSymbolicReference(key: "file-import", value: snippet.sha1Digest)
  }
}

private extension Date {
  /// True if the receiver and `other` are "close enough"
  func closeEnough(to other: Date) -> Bool {
    return abs(timeIntervalSince(other)) < 1
  }
}
