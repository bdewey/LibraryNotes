// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

public struct PageManifest {
  private let _data: [String: PageProperties]

  public init() {
    _data = [:]
  }

  private init(data: [String: PageProperties]) {
    self._data = data
  }

  public func insert(_ pageProperties: PageProperties) -> PageManifest {
    var data = _data
    data[UUID().uuidString] = pageProperties
    return PageManifest(data: data)
  }
}

public struct TextSnippetArchiveVersion {
  public let timestamp: Date
  public let digest: String
}

public struct NoteArchive {
  /// Default initializer; creates an empty NoteBundle.
  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  /// Rules used to parse challenge templates.
  public let parsingRules: ParsingRules

  private var archive = TextSnippetArchive()

  private var pagePropertiesVersionHistory: [TextSnippetArchiveVersion] = []

  /// All challenge templates in the bundle.
  internal var challengeTemplates = ChallengeTemplateCollection()

  /// Mapping of page UUID (constant across revisions) to the current page properties digest
  public internal(set) var pageProperties: [String: String] = [:]

  mutating public func insertNote(_ text: String, timestamp: Date) throws {
    let propertiesDigest = try archivePageProperties(from: text, timestamp: timestamp)
    pageProperties[UUID().uuidString] = propertiesDigest
    archivePageManifestVersion(timestamp: timestamp)
  }

  private mutating func archivePageManifestVersion(timestamp: Date) {
    let version = TextSnippetArchiveVersion(timestamp: timestamp, digest: archivePageManifest())
    if let existingVersion = pagePropertiesVersionHistory.last,
      let oldManifestSnippet = archive.snippetDigestIndex[existingVersion.digest],
      let newManifestSnippet = archive.snippetDigestIndex[version.digest] {
      oldManifestSnippet.encodeAsDiff(from: newManifestSnippet)
    }
    pagePropertiesVersionHistory.append(version)
  }

  private mutating func archivePageManifest() -> String {
    let manifest = pageProperties
      .map( { "\($0.key) \($0.value)" } )
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
