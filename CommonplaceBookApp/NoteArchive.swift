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

  /// Rules used to parse challenge templates.
  public let parsingRules: ParsingRules

  private var archive = TextSnippetArchive()

  private var pagePropertiesVersionHistory: [NoteArchiveVersion] = []

  /// All challenge templates in the bundle.
  internal var challengeTemplates = ChallengeTemplateCollection()

  /// Mapping of page UUID (constant across revisions) to the current page properties digest
  public internal(set) var pageProperties: [String: String] = [:]

  public var versions: [Date] {
    return pagePropertiesVersionHistory.map { $0.timestamp }
  }

  public func textSerialized() -> String {
    return archive.textSerialized()
  }

  mutating public func insertNote(_ text: String, timestamp: Date) throws {
    let propertiesDigest = try archivePageProperties(from: text, timestamp: timestamp)
    pageProperties[UUID().uuidString] = propertiesDigest
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

  private mutating func archivePageManifest() -> String {
    let manifest = pageProperties
      .map({ "\($0.key) \($0.value)" })
      .sorted()
      .joined(separator: "\n")
    let manifestSnippet = archive.insert(manifest)
    return manifestSnippet.sha1Digest
  }

  /// Synchronously extract properties & challenge templates from the contents of a file.
  mutating func archivePageProperties(
    from text: String,
    timestamp: Date
  ) throws -> String {
    let nodes = parsingRules.parse(text)
    let challengeTemplateKeys = nodes.archiveChallengeTemplates(to: &archive)
    let properties = PageProperties(
      sha1Digest: text.sha1Digest(),
      timestamp: timestamp,
      hashtags: nodes.hashtags,
      title: String(nodes.title.split(separator: "\n").first ?? ""),
      cardTemplates: challengeTemplateKeys.map { $0.description }
    )
    let propertiesSnippet = try properties.makeSnippet()
    archive.insert(propertiesSnippet)
    return properties.sha1Digest
  }
}
