// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

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
      self.pageProperties = try NoteArchive.getPageManifest(
        from: archive,
        manifestIdentifier: identifier
      )
    } else {
      self.pageProperties = [:]
    }
  }

  /// Rules used to parse challenge templates.
  public let parsingRules: ParsingRules

  private var archive = TextSnippetArchive()

  private var pagePropertiesVersionHistory: [NoteArchiveVersion] = []

  /// Mapping of page UUID (constant across revisions) to the current page properties digest
  public internal(set) var pageProperties: [String: String] = [:]

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
    pageProperties[key] = propertiesSnippet.sha1Digest
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
    guard let propertiesDigest = pageProperties[pageIdentifier],
      let propertiesSnippet = archive.snippetDigestIndex[propertiesDigest] else {
        throw RetrievalError.noSuchPage(pageIdentifier)
    }
    return (propertiesSnippet, try PageProperties(propertiesSnippet))
  }

  public mutating func updateText(
    for pageIdentifier: String,
    to text: String,
    at timestamp: Date
  ) throws {
    let (existingSnippet, existingProperties) = try currentPageProperties(for: pageIdentifier)
    let (newSnippet, newProperties) = try archivePageProperties(from: text, timestamp: timestamp)
    existingSnippet.encodeAsDiff(from: newSnippet)
    guard let existingTextSnippet = archive.snippetDigestIndex[existingProperties.sha1Digest] else {
      throw RetrievalError.noSuchPage(existingProperties.sha1Digest)
    }
    guard let newTextSnippet = archive.snippetDigestIndex[newProperties.sha1Digest] else {
      throw RetrievalError.noSuchPage(newProperties.sha1Digest)
    }
    existingTextSnippet.encodeAsDiff(from: newTextSnippet)
    pageProperties[pageIdentifier] = newSnippet.sha1Digest
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
    let manifest = pageProperties
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
