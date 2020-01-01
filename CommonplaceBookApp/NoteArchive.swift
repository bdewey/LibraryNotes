// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CoreSpotlight
import Foundation
import MiniMarkdown
import MobileCoreServices
import Yams

public struct NoteArchive {
  /// Default initializer; creates an empty NoteBundle.
  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  /// Deserialize an archive.
  public init(parsingRules: ParsingRules, textSerialization: String) throws {
    self.parsingRules = parsingRules
    self.archive = try TextSnippetArchive(textSerialization: textSerialization)
    self.notePropertiesVersionHistory = try NoteArchive.getVersionHistory(from: archive)
    if let identifier = notePropertiesVersionHistory.last?.digest {
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

  /// Archive containing the notes.
  private var archive = TextSnippetArchive()

  /// All persisted versions of the archive. We store deltas between versions so *hopefully* it's not too expensive to keep everything around.
  private var notePropertiesVersionHistory: [Version] = []

  /// Mapping of page UUID (constant across revisions) to the current page properties digest
  private var pagePropertyDigests: [Note.Identifier: String] = [:]

  /// A mapping of page UUID to page contents loaded from the archive.
  private var pageContentsCache: [Note.Identifier: PageContents] = [:]

  /// Returns the current mapping of page id to page properties
  public var noteProperties: [Note.Identifier: NoteProperties] {
    let archiveVersion = pagePropertyDigests.compactMapValues { propertyDigest -> NoteProperties? in
      guard
        let snippet = archive.snippets[propertyDigest],
        let properties = try? NoteProperties(snippet) else {
        return nil
      }
      return properties
    }
    let cacheVersion = pageContentsCache.compactMapValues { $0.noteProperties }
    return archiveVersion.merging(cacheVersion, uniquingKeysWith: { _, new in new })
  }

  public enum SerializationError: Error {
    /// There is no symbolic reference to the "versions" array in the archive.
    case noVersionReference
    /// Unimplemented functionality
    case notImplemented
  }

  public enum RetrievalError: Error {
    /// A page with the given page identifier does not exist.
    case noSuchPage(Note.Identifier)
    /// A text snippet with the given sha1Digest does not exist.
    case noSuchText(String)
    /// A page manifest with a given sha1Digest does not exist.
    case noSuchManifest(String)
    /// There is no specific text for a challenge template in the archive.
    case noSuchTemplateKey(String)
    /// The challenge template uses an unkown template class.
    case noSuchTemplateClass(String)
  }

  /// Timestamps of all of the versions stored in this archive.
  public var versions: [Date] {
    return notePropertiesVersionHistory.map { $0.timestamp }
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
    assert(pageContentsCache.allSatisfy { !$0.value.dirty })
    return archive.textSerialized()
  }

  /// APIv2: Retrieve a Note for an identifier.
  public func note(noteIdentifier: Note.Identifier, challengeTemplateCache: NSCache<NSString, ChallengeTemplate>) throws -> Note {
    guard let properties = noteProperties[noteIdentifier] else {
      throw RetrievalError.noSuchPage(noteIdentifier)
    }
    // Not all notes have text, so it's OK for this to fail and be nil
    let text = try? currentText(for: noteIdentifier)
    let challengeTemplates = properties.cardTemplates.compactMap { keyString -> ChallengeTemplate? in
      guard let key = ChallengeTemplateArchiveKey(keyString) else { return nil }
      return try? challengeTemplate(for: key, challengeTemplateCache: challengeTemplateCache)
    }
    return Note(metadata: properties.asNoteMetadata(), text: text, challengeTemplates: challengeTemplates)
  }

  /// APIv2: Update a note. In this API, there's no notion of having the text & the challenge templates being stale and computed
  /// by the storage layer; the caller must ensure that `note` is consistent before calling this API.
  ///
  /// However, to prevent version explosion, this does write to `pageContentsCache`. You must later call `archivePageManfiestVersion`
  /// to write contents from the cache into the archive.
  public mutating func updateNote(_ note: Note, for noteIdentifier: Note.Identifier) throws {
    var pageContents = pageContentsCache[noteIdentifier, default: PageContents()]
    // Insert all templates
    let challengeTemplateKeys = try note.challengeTemplates
      .map {
        try insertChallengeTemplate($0).description
      }
      .sorted()
    pageContents.setChallengeTemplateKeys(challengeTemplateKeys)
    pageContents.setText(note.text)
    pageContents.setNoteMetadata(note.metadata)
    pageContentsCache[noteIdentifier] = pageContents
  }

  /// APIv2: Creates a new note.
  public mutating func createNote(_ note: Note) throws -> Note.Identifier {
    let identifier = Note.Identifier()
    try updateNote(note, for: identifier)
    return identifier
  }

  /// Creates a new page with the given text.
  /// - returns: An identifier that can be used to return the current version of this page
  ///            at any point in time.
  @discardableResult
  public mutating func insertNote(
    _ text: String,
    contentChangeTime timestamp: Date
  ) throws -> Note.Identifier {
    var pageContents = PageContents()
    pageContents.setText(text, modifiedTimestamp: timestamp)
    let key = Note.Identifier()
    pageContentsCache[key] = pageContents
    return key
  }

  /// Inserts "naked properties" into the archive -- PageProperties that are directly manipulated, not derived from text.
  public mutating func insertNoteProperties(_ noteProperties: NoteProperties) -> Note.Identifier {
    var pageContents = PageContents(noteProperties: noteProperties)
    pageContents.dirty = true
    let key = Note.Identifier()
    pageContentsCache[key] = pageContents
    return key
  }

  public mutating func insertChallengeTemplate(
    _ challengeTemplate: ChallengeTemplate
  ) throws -> ChallengeTemplateArchiveKey {
    try archive.insert(challengeTemplate)
  }

  /// Removes a note from the archive.
  /// - throws: `RetrievalError.noSuchPage` if the page does not exist.
  public mutating func removeNote(for noteIdentifier: Note.Identifier) {
    pageContentsCache.removeValue(forKey: noteIdentifier)
    pagePropertyDigests.removeValue(forKey: noteIdentifier)
  }

  /// Gets the current version of the text for a particular page.
  public func currentText(for noteIdentifier: Note.Identifier) throws -> String {
    if let text = pageContentsCache[noteIdentifier]?.text {
      return text
    }
    let properties = try currentPageProperties(for: noteIdentifier).properties
    guard let digest = properties.sha1Digest, let noteSnippet = archive.snippets[digest] else {
      throw RetrievalError.noSuchText(properties.sha1Digest ?? "nil")
    }
    return noteSnippet.text
  }

  /// Gets a `ChallengeTemplate` given its key.
  /// - parameter key: A reference to a specific challenge template in the archive.
  /// - throws: `RetrievalError.noSuchTemplateKey` if the specific challenge text does not exist in the archive.
  /// - throws: `RetrievalError.noSuchTemplateClass` if this key uses an unknown challenge template.
  public func challengeTemplate(
    for key: ChallengeTemplateArchiveKey,
    challengeTemplateCache: NSCache<NSString, ChallengeTemplate>
  ) throws -> ChallengeTemplate {
    let cacheKey: NSString = key.description as NSString
    if let cachedTemplate = challengeTemplateCache.object(forKey: cacheKey) {
      return cachedTemplate
    }
    guard let snippet = archive.snippets[key.digest] else {
      throw RetrievalError.noSuchTemplateKey(key.digest)
    }
    guard let klass = ChallengeTemplateType.classMap[key.type] else {
      throw RetrievalError.noSuchTemplateClass(key.type)
    }
    if let fromYaml = try? YAMLDecoder().decode(klass, from: snippet.text, userInfo: [.markdownParsingRules: parsingRules]) {
      fromYaml.templateIdentifier = key.digest
      challengeTemplateCache.setObject(fromYaml, forKey: cacheKey)
      return fromYaml
    }
    // Try encoding the snippet as a YAML string, then decoding as klass.
    // This will accomodate single-value-container types that didn't go through the YAML encoder.
    let encodedText = try YAMLEncoder().encode(snippet.text)
    let yamlRetry = try YAMLDecoder().decode(klass, from: encodedText, userInfo: [.markdownParsingRules: parsingRules])
    yamlRetry.templateIdentifier = key.digest
    challengeTemplateCache.setObject(yamlRetry, forKey: cacheKey)
    return yamlRetry
  }

  /// Updates the text associated with `noteIdentifier` to `text`, creating a new version
  /// in the process.
  ///
  /// - parameter noteIdentifier: The page identifier to update
  /// - parameter text: The new text of the page
  /// - parameter noteProperties: Computed noteProperties to match the text. If nil, the existing properties are marked stale and computed later.
  /// - parameter contentChangeTime: The *content change* timestamp of the text
  /// - note: If `text` is not different from the current value associated with `noteIdentifier`,
  ///         this operation is a no-op. No new version gets created.
  public mutating func updateText(
    for noteIdentifier: Note.Identifier,
    to text: String,
    noteProperties: NoteProperties? = nil,
    contentChangeTime timestamp: Date
  ) {
    if pageContentsCache[noteIdentifier] != nil {
      pageContentsCache[noteIdentifier]!.setText(text, properties: noteProperties, modifiedTimestamp: timestamp)
      return
    } else {
      var contents = PageContents()
      contents.setText(text, properties: noteProperties, modifiedTimestamp: timestamp)
      pageContentsCache[noteIdentifier] = contents
    }
  }

  /// Updates naked page properties.
  /// - precondition: noteProperties is not associated with content
  /// - parameter noteIdentifier: The permanent identifier for the properties
  /// - parameter noteProperties: The properties to update.
  public mutating func updatePageProperties(
    for noteIdentifier: Note.Identifier,
    to noteProperties: NoteProperties
  ) {
    precondition(noteProperties.sha1Digest == nil)
    pageContentsCache[noteIdentifier] = PageContents(dirty: true, noteProperties: noteProperties)
  }

  /// Updates all page properties that are stale in the contents cache.
  /// - returns: How many page properties were updated.
  @discardableResult
  public mutating func batchUpdatePageProperties() -> Int {
    let updated = archive.updatePageProperties(
      in: pageContentsCache.filter { $0.value.notePropertiesStale },
      parsingRules: parsingRules
    )
    pageContentsCache.merge(updated, uniquingKeysWith: { _, new in new })
    let items = updated.compactMap(searchableItem)
    addItemsToIndex(items)
    return updated.count
  }

  /// Creates a new Version representing the current page manifest in the archive.
  /// - parameter timestamp: The version timestamp.
  /// - throws: Any errors creating the symbolic reference
  public mutating func archivePageManifestVersion(timestamp: Date) throws {
    try flushContentsCache()
    let version = Version(timestamp: timestamp, digest: archivePageManifest())
    if let existingVersion = notePropertiesVersionHistory.last,
      existingVersion.digest == version.digest {
      // The new version is identical to the old version -- no-op.
      return
    }
    if let existingVersion = notePropertiesVersionHistory.last,
      let oldManifestSnippet = archive.snippets[existingVersion.digest],
      let newManifestSnippet = archive.snippets[version.digest] {
      newManifestSnippet.encodeAsDiff(from: nil)
      oldManifestSnippet.encodeAsDiff(from: newManifestSnippet)
    }
    notePropertiesVersionHistory.append(version)
    try archiveVersionHistory()
  }
}

// MARK: - Import

public extension NoteArchive {
  /// Adds the contents of a file to the archive as a new note.
  mutating func importFile(
    named fileName: String,
    text: String,
    contentChangeDate: Date,
    importDate: Date
  ) throws {
    var importRecords = try getFileImportRecords()
    if let importRecord = importRecords[fileName] {
      if !contentChangeDate.closeEnough(to: importRecord.changeDate) {
        updateText(
          for: importRecord.noteIdentifier,
          to: text,
          contentChangeTime: contentChangeDate
        )
      }
    } else {
      let noteIdentifier = try insertNote(
        text,
        contentChangeTime: contentChangeDate
      )
      importRecords[fileName] = FileImportRecord(
        noteIdentifier: noteIdentifier,
        changeDate: contentChangeDate
      )
      try archiveFileImportRecords(importRecords)
    }
  }
}

// MARK: - Indexing

public extension NoteArchive {
  /// Adds all of the current contents of this NoteArchive to Spotlight.
  func addToSpotlight(completion: ((Error?) -> Void)? = nil) {
    do {
      let toIndex = try noteProperties.map { noteIdentifier, noteProperties in
        (noteIdentifier, noteProperties, try currentText(for: noteIdentifier))
      }
      let items = toIndex.map(searchableItem)
      CSSearchableIndex.default().deleteAllSearchableItems { _ in
        self.addItemsToIndex(items, completion: completion)
      }
    } catch {
      completion?(error)
    }
  }

  private func addItemsToIndex(_ items: [CSSearchableItem], completion: ((Error?) -> Void)? = nil) {
    DDLogInfo("Indexing \(items.count) item(s)")
    CSSearchableIndex.default().indexSearchableItems(items) { error in
      if let error = error {
        DDLogError("Indexing error: \(error.localizedDescription)")
      } else {
        DDLogInfo("Indexing finished without error")
      }
      completion?(error)
    }
  }

  private func searchableItem(
    noteIdentifier: Note.Identifier,
    noteProperties: NoteProperties,
    pageContents: String
  ) -> CSSearchableItem {
    let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypePlainText as String)
    attributes.title = noteProperties.title
    attributes.keywords = noteProperties.hashtags
    attributes.contentDescription = pageContents
    let item = CSSearchableItem(uniqueIdentifier: noteIdentifier.rawValue, domainIdentifier: "org.brians-brain.CommonplaceBookApp", attributeSet: attributes)
    return item
  }

  private func searchableItem(
    noteIdentifier: Note.Identifier,
    pageContents: PageContents
  ) -> CSSearchableItem? {
    guard let noteProperties = pageContents.noteProperties else {
      return nil
    }
    return searchableItem(noteIdentifier: noteIdentifier, noteProperties: noteProperties, pageContents: pageContents.text ?? "")
  }
}

// MARK: - Private

private extension NoteArchive {
  /// A timestamp & digest. The digest references the page manifest at that version.
  struct Version: LosslessStringConvertible {
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

  /// An in-memory cache record of the contents of a page
  struct PageContents {
    /// Page text. If nil, we are caching raw properties
    var text: String?
    var modifiedTimestamp: Date
    var dirty: Bool
    var noteProperties: NoteProperties?
    var notePropertiesStale: Bool

    init(
      text: String? = nil,
      modifiedTimestamp: Date? = nil,
      dirty: Bool = false,
      noteProperties: NoteProperties? = nil,
      notePropertiesStale: Bool = false
    ) {
      self.text = text
      self.modifiedTimestamp = modifiedTimestamp ?? noteProperties?.timestamp ?? Date.distantPast
      self.dirty = dirty
      self.noteProperties = noteProperties
      self.notePropertiesStale = notePropertiesStale
    }

    /// Updates text.
    mutating func setText(_ text: String, properties: NoteProperties? = nil, modifiedTimestamp: Date) {
      self.text = text
      self.modifiedTimestamp = modifiedTimestamp
      dirty = true
      if let properties = properties {
        noteProperties = properties
        notePropertiesStale = false
      } else {
        notePropertiesStale = true
      }
    }

    mutating func setText(_ text: String?) {
      guard text != self.text else { return }
      self.text = text
      dirty = true
    }

    mutating func setChallengeTemplateKeys(_ challengeTemplateKeys: [String]) {
      guard challengeTemplateKeys != noteProperties?.cardTemplates else { return }
      if noteProperties == nil {
        noteProperties = NoteProperties(cardTemplates: challengeTemplateKeys)
      } else {
        noteProperties?.cardTemplates = challengeTemplateKeys
      }
      dirty = true
    }

    mutating func setNoteMetadata(_ noteMetadata: Note.Metadata) {
      var noteProperties = self.noteProperties ?? NoteProperties()
      noteProperties.title = noteMetadata.title
      noteProperties.hashtags = noteMetadata.hashtags.sorted()
      noteProperties.timestamp = noteMetadata.timestamp
      self.noteProperties = noteProperties
      dirty = true
    }
  }

  /// Represents a specific file that has been imported into the archive.
  struct FileImportRecord: Codable {
    /// The UUID representing the page that holds the file contents.
    let noteIdentifier: Note.Identifier
    /// The changeDate of the file at the time it was imported.
    let changeDate: Date
  }

  func getFileImportRecords() throws -> [String: FileImportRecord] {
    guard
      let snippetIdentifier = archive.symbolicReferences["file-import"],
      let snippet = archive.snippets[snippetIdentifier] else {
      return [:]
    }
    return try YAMLDecoder().decode([String: FileImportRecord].self, from: snippet.text)
  }

  mutating func archiveFileImportRecords(_ records: [String: FileImportRecord]) throws {
    let encoded = try YAMLEncoder().encode(records)
    try archive.setSymbolicReference(key: "file-import", text: encoded)
  }

  /// Writes any dirty content from `pageContentsCache` to `archive`
  /// - returns: How many modified pages were updated
  @discardableResult
  mutating func flushContentsCache() throws -> Int {
    var modifiedPageCount = 0
    // Make sure all properties are up to date
    batchUpdatePageProperties()
    for (noteIdentifier, contents) in pageContentsCache where contents.dirty {
      // If there is text associated with these contents, make sure the text is in the archive.
      let newTextSnippet = contents.text.map { archive.insert($0) }
      // Because we updated all page properties, safe to force-unwrap
      let newPropertiesSnippet = archive.insert(try contents.noteProperties!.makeSnippet())
      pageContentsCache[noteIdentifier]?.dirty = false
      modifiedPageCount += 1

      // If there was already content for this page in the archive, delta-encode it.
      guard let (existingPropertiesSnippet, existingProperties) = try? currentPageProperties(for: noteIdentifier) else {
        pagePropertyDigests[noteIdentifier] = newPropertiesSnippet.sha1Digest
        continue
      }
      // New content is the same as the old content
      if newPropertiesSnippet.sha1Digest == existingPropertiesSnippet.sha1Digest {
        continue
      }
      newPropertiesSnippet.encodeAsDiff(from: nil)
      existingPropertiesSnippet.encodeAsDiff(from: newPropertiesSnippet)
      // If the properties are associated with text, delta-encode the text.
      if let digest = existingProperties.sha1Digest {
        guard
          let existingTextSnippet = archive.snippets[digest]
        else {
          throw RetrievalError.noSuchText(existingProperties.sha1Digest ?? "nil")
        }
        // Note the content can be the same but the properties can have different timestamps
        // So, check and make sure we didn't wind up with identical content before delta encoding.
        if let textSnippet = newTextSnippet, textSnippet.sha1Digest != existingTextSnippet.sha1Digest {
          textSnippet.encodeAsDiff(from: nil)
          existingTextSnippet.encodeAsDiff(from: newTextSnippet)
        }
      }
      pagePropertyDigests[noteIdentifier] = newPropertiesSnippet.sha1Digest
    }
    return modifiedPageCount
  }

  /// Gets the page properties for a page identifier.
  ///
  /// - note: We return both the snippet and the decoded properties so we have the option of adding delta encoding to the snippet
  /// if we are updating the contents of the page.
  ///
  /// - parameter noteIdentifier: the page to retrieve properties for
  /// - returns: A tuple containing the TextSnippet of serialized properties and the deserialized version of the properties
  /// - throws: `RetrievalError.noSuchPage` if the page was not found in the archive.
  func currentPageProperties(
    for noteIdentifier: Note.Identifier
  ) throws -> (snippet: TextSnippet, properties: NoteProperties) {
    guard let propertiesDigest = pagePropertyDigests[noteIdentifier],
      let propertiesSnippet = archive.snippets[propertiesDigest] else {
      throw RetrievalError.noSuchPage(noteIdentifier)
    }
    return (propertiesSnippet, try NoteProperties(propertiesSnippet))
  }

  /// Writes the version history array into the archive.
  /// - note: We keep only one copy of the version array in the archive
  /// - throws: `TextSnippetArchive.Error` if there is a problem creating the symbolic reference to the version snippet
  ///           in the archive.
  mutating func archiveVersionHistory() throws {
    let history = notePropertiesVersionHistory.reversed()
      .map { $0.description }.joined(separator: "\n")
    try archive.setSymbolicReference(key: "versions", text: history)
  }

  /// Loads the version array from the archive.
  /// - throws: `SerializationError` if we can't find the version array
  static func getVersionHistory(
    from archive: TextSnippetArchive
  ) throws -> [Version] {
    guard
      let versionDigest = archive.symbolicReferences["versions"],
      let versionSnippet = archive.snippets[versionDigest] else {
      throw SerializationError.noVersionReference
    }
    return versionSnippet.text.split(separator: "\n")
      .reversed()
      .map(String.init)
      .compactMap(Version.init)
  }

  /// Writes the current `pagePropertyDigests` into the archive.
  /// - returns: The sha1Digest of the snippet created to hold this version of the manifest.
  mutating func archivePageManifest() -> String {
    let manifest = pagePropertyDigests
      .map { "\($0.key) \($0.value)" }
      .sorted()
      .joined(separator: "\n")
    let manifestSnippet = archive.insert(manifest)
    return manifestSnippet.sha1Digest
  }

  /// Loads a specific version of the page manifest from the archive.
  /// - parameter archive: The archive to load from.
  /// - parameter manifestIdentifier: The sha1Digest of a specific version of a manifest.
  /// - returns: a dictionary mapping noteIdentifiers to sha1Digests of specific versions of pages.
  /// - throws: `RetrievalError.noSuchPage` if the manifest is not in the archive.
  static func getPageManifest(
    from archive: TextSnippetArchive,
    manifestIdentifier: String
  ) throws -> [Note.Identifier: String] {
    guard let manifestSnippet = archive.snippets[manifestIdentifier] else {
      throw RetrievalError.noSuchManifest(manifestIdentifier)
    }
    let keyValuePairs = manifestSnippet.text
      .split(separator: "\n")
      .compactMap { line -> (Note.Identifier, String)? in
        let components = line.split(separator: " ")
        guard components.count == 2 else { return nil }
        return (Note.Identifier(rawValue: String(components[0])), String(components[1]))
      }
    return Dictionary(uniqueKeysWithValues: keyValuePairs)
  }

  /// Synchronously extract properties & challenge templates from the contents of a file.
  mutating func archivePageProperties(
    from text: String,
    timestamp: Date
  ) throws -> (snippet: TextSnippet, properties: NoteProperties) {
    let textSnippet = archive.insert(text)
    let nodes = parsingRules.parse(text)
    let challengeTemplateKeys = nodes.archiveChallengeTemplates(to: &archive)
    let properties = NoteProperties(
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

private extension TextSnippetArchive {
  /// Given an array of pageContents, computes updated PageProperties for any that are stale.
  /// - note: This is mutating because we have to update any challenge templates in the archive
  /// - returns: An array where every entry has non-stale properties.
  mutating func updatePageProperties(
    in pageContents: [Note.Identifier: NoteArchive.PageContents],
    parsingRules: ParsingRules
  ) -> [Note.Identifier: NoteArchive.PageContents] {
    pageContents.mapValues { pageContent in
      guard
        pageContent.notePropertiesStale,
        let text = pageContent.text
      else {
        return pageContent
      }
      var pageContent = pageContent
      let nodes = parsingRules.parse(text)
      let challengeTemplateKeys = nodes.archiveChallengeTemplates(to: &self)
      pageContent.noteProperties = NoteProperties(
        sha1Digest: TextSnippet(text).sha1Digest,
        timestamp: pageContent.modifiedTimestamp,
        hashtags: nodes.hashtags,
        title: String(nodes.title.split(separator: "\n").first ?? ""),
        cardTemplates: challengeTemplateKeys.map { $0.description }
      )
      pageContent.notePropertiesStale = false
      return pageContent
    }
  }
}

private extension Date {
  /// True if the receiver and `other` are "close enough"
  func closeEnough(to other: Date) -> Bool {
    return abs(timeIntervalSince(other)) < 1
  }
}
