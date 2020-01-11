// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import CoreSpotlight
import DataCompression
import MiniMarkdown
import MobileCoreServices
import UIKit

/// Concrete implementation of NoteStorage that keeps data in a file system package with a compressed TextSnippetArchive and compressed study log.
public final class NoteDocumentStorage: UIDocument, NoteStorage {
  /// Designated initializer.
  /// - parameter fileURL: The URL of the document
  /// - parameter parsingRules: Defines how to parse markdown inside the notes
  public init(fileURL url: URL, parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
    self.noteArchive = NoteArchive(parsingRules: parsingRules)
    self.notesDidChange = notesDidChangeSubject.eraseToAnyPublisher()
    super.init(fileURL: url)
  }

  /// How to parse Markdown in the snippets
  public let parsingRules: ParsingRules

  /// Top-level FileWrapper for our contents
  private var topLevelFileWrapper = FileWrapper(directoryWithFileWrappers: [:])

  /// FileWrapper for image assets.
  private var assetsFileWrapper: FileWrapper {
    if let fileWrapper = topLevelFileWrapper.fileWrappers![BundleWrapperKey.assets] {
      return fileWrapper
    }
    let fileWrapper = FileWrapper(directoryWithFileWrappers: [:])
    fileWrapper.preferredFilename = BundleWrapperKey.assets
    topLevelFileWrapper.addFileWrapper(fileWrapper)
    return fileWrapper
  }

  /// The actual document contents.
  internal var noteArchive: NoteArchive

  /// Protects noteArchive.
  internal let noteArchiveQueue = DispatchQueue(label: "org.brians-brain.note-archive-document")

  /// Holds the outcome of every study session.
  public internal(set) var studyLog = StudyLog()

  /// If there is every an I/O error, this contains it.
  public private(set) var previousError: Error?

  private let challengeTemplateCache = NSCache<NSString, ChallengeTemplate>()

  /// Accessor for the page properties.
  public var noteProperties: [Note.Identifier: NoteProperties] {
    return noteArchiveQueue.sync {
      noteArchive.noteProperties
    }
  }

  public var allMetadata: [Note.Identifier: Note.Metadata] {
    noteProperties.mapValues { $0.asNoteMetadata() }
  }

  public func note(noteIdentifier: Note.Identifier) throws -> Note {
    return try noteArchiveQueue.sync {
      try noteArchive.note(noteIdentifier: noteIdentifier, challengeTemplateCache: challengeTemplateCache)
    }
  }

  public func eligibleChallengeIdentifiers(
    before date: Date,
    limitedTo noteIdentifier: Note.Identifier?
  ) throws -> [ChallengeIdentifier] {
    guard let noteIdentifier = noteIdentifier else {
      assertionFailure("Note documents don't support returning identifiers from all documents")
      return []
    }
    let suppressionDates = studyLog.identifierSuppressionDates()
    return try noteArchiveQueue.sync {
      let note = try noteArchive.note(noteIdentifier: noteIdentifier, challengeTemplateCache: challengeTemplateCache)
      let eligibleCards = note.challengeTemplates.cards
         .filter { challenge -> Bool in
           guard let suppressionDate = suppressionDates[challenge.challengeIdentifier] else {
             return true
           }
           return date >= suppressionDate
         }
      return eligibleCards.map { $0.challengeIdentifier }
    }
  }

  public func challenge(
    noteIdentifier: Note.Identifier,
    challengeIdentifier: ChallengeIdentifier
  ) throws -> Challenge {
    return try noteArchiveQueue.sync {
      try noteArchive.challenge(noteIdentifier: noteIdentifier, challengeIdentifier: challengeIdentifier, challengeTemplateCache: challengeTemplateCache)
    }
  }

  public func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws {
    try noteArchiveQueue.sync {
      let existingNote = try noteArchive.note(noteIdentifier: noteIdentifier, challengeTemplateCache: challengeTemplateCache)
      let updatedNote = updateBlock(existingNote)
      try noteArchive.updateNote(updatedNote, for: noteIdentifier)
    }
    invalidateSavedSnippets()
    schedulePropertyBatchUpdate()
  }

  public func createNote(_ note: Note) throws -> Note.Identifier {
    let identifier = try noteArchiveQueue.sync {
      try noteArchive.createNote(note)
    }
    invalidateSavedSnippets()
    schedulePropertyBatchUpdate()
    return identifier
  }

  public func flush() {
    save(to: fileURL, for: .forOverwriting, completionHandler: nil)
  }

  public let notesDidChange: AnyPublisher<Void, Never>
  private let notesDidChangeSubject = PassthroughSubject<Void, Never>()

  private var propertyBatchUpdateTimer: Timer?

  private func schedulePropertyBatchUpdate() {
    guard propertyBatchUpdateTimer == nil else { return }
    propertyBatchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { _ in
      let count = self.noteArchiveQueue.sync {
        self.noteArchive.batchUpdatePageProperties()
      }
      // swiftlint:disable:next empty_count
      if count > 0 {
        self.notesDidChangeSubject.send()
      }
      self.propertyBatchUpdateTimer = nil
    })
  }

  public func deleteNote(noteIdentifier: Note.Identifier) throws {
    noteArchiveQueue.sync {
      noteArchive.removeNote(for: noteIdentifier)
    }
    CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [noteIdentifier.rawValue], completionHandler: nil)
    invalidateSavedSnippets()
    notesDidChangeSubject.send()
  }

  private enum BundleWrapperKey {
    static let assets = "assets"
    static let compressedSnippets = "text.snippets.gz"
    static let compressedStudyLog = "study.log.gz"
    static let snippets = "text.snippets"
    static let studyLog = "study.log"
  }

  /// Deserialize `noteArchive` from `contents`
  /// - precondition: `contents` is a directory FileWrapper with a "text.snippets" regular file
  /// - throws: NSError in the NoteArchiveDocument domain on any error
  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard let wrapper = contents as? FileWrapper, wrapper.isDirectory else {
      throw error(for: .unexpectedContentType)
    }
    topLevelFileWrapper = wrapper
    studyLog = NoteDocumentStorage.loadStudyLog(from: wrapper)
    do {
      let noteArchive = try NoteDocumentStorage.loadNoteArchive(
        from: wrapper,
        parsingRules: parsingRules
      )
      noteArchive.addToSpotlight()
      let noteProperties = noteArchive.noteProperties
      noteArchiveQueue.sync { self.noteArchive = noteArchive }
      DDLogInfo("Loaded \(noteProperties.count) pages")
      notesDidChangeSubject.send()
    } catch {
      throw wrapError(code: .textSnippetsDeserializeError, innerError: error)
    }
  }

  /// Serialize `noteArchive` to `topLevelFileWrapper` and return `topLevelFileWrapper` for saving
  public override func contents(forType typeName: String) throws -> Any {
    precondition(topLevelFileWrapper.isDirectory)
    if topLevelFileWrapper.fileWrappers![BundleWrapperKey.compressedSnippets] == nil {
      topLevelFileWrapper.addFileWrapper(try compressedSnippetsFileWrapper())
    }
    if topLevelFileWrapper.fileWrappers![BundleWrapperKey.compressedStudyLog] == nil {
      guard let compressedLog = studyLog.description.data(using: .utf8)!.gzip() else {
        throw error(for: .couldNotCompressStudyLog)
      }
      let logWrapper = FileWrapper(
        regularFileWithContents: compressedLog
      )
      logWrapper.preferredFilename = BundleWrapperKey.compressedStudyLog
      topLevelFileWrapper.addFileWrapper(logWrapper)
    }
    purgeUnneededWrappers(from: topLevelFileWrapper)
    DDLogInfo("Saving: \(topLevelFileWrapper.fileWrappers!.keys)")
    return topLevelFileWrapper
  }

  public override func handleError(_ error: Error, userInteractionPermitted: Bool) {
    previousError = error
    super.handleError(error, userInteractionPermitted: userInteractionPermitted)
  }

  /// Lets the UIDocument infrastructure know we have content to save, and also
  /// discards our in-memory representation of the snippet file wrapper.
  internal func invalidateSavedSnippets() {
    if let compressedWrapper = topLevelFileWrapper.fileWrappers![BundleWrapperKey.compressedSnippets] {
      topLevelFileWrapper.removeFileWrapper(compressedWrapper)
    }
    updateChangeCount(.done)
  }

  internal func invalidateSavedStudyLog() {
    if let archiveWrapper = topLevelFileWrapper.fileWrappers![BundleWrapperKey.compressedStudyLog] {
      topLevelFileWrapper.removeFileWrapper(archiveWrapper)
    }
    updateChangeCount(.done)
  }

  /// Gets data contained in a file wrapper
  /// - parameter fileWrapperKey: A path to a named file wrapper. E.g., "assets/image.png"
  /// - returns: The data contained in that wrapper if it exists, nil otherwise.
  public func data<S: StringProtocol>(for fileWrapperKey: S) -> Data? {
    var currentWrapper = topLevelFileWrapper
    for pathComponent in fileWrapperKey.split(separator: "/") {
      guard let nextWrapper = currentWrapper.fileWrappers?[String(pathComponent)] else {
        return nil
      }
      currentWrapper = nextWrapper
    }
    return currentWrapper.regularFileContents
  }

  public var assetKeys: [String] {
    guard let assetFileWrappers = assetsFileWrapper.fileWrappers else {
      return []
    }
    return assetFileWrappers.keys.map {
      "\(BundleWrapperKey.assets)/\($0)"
    }
  }
}

/// Load / save support
private extension NoteDocumentStorage {
  static func loadNoteArchive(
    from wrapper: FileWrapper,
    parsingRules: ParsingRules
  ) throws -> NoteArchive {
    let maybeData = wrapper.fileWrappers?[BundleWrapperKey.compressedSnippets]?.regularFileContents?.gunzip()
      ?? wrapper.fileWrappers?[BundleWrapperKey.snippets]?.regularFileContents
    guard
      let data = maybeData,
      let text = String(data: data, encoding: .utf8) else {
      // Is this an error? Or expected for a new document?
      return NoteArchive(parsingRules: parsingRules)
    }
    return try NoteArchive(parsingRules: parsingRules, textSerialization: text)
  }

  static func loadStudyLog(from wrapper: FileWrapper) -> StudyLog {
    let maybeData = wrapper.fileWrappers?[BundleWrapperKey.compressedStudyLog]?.regularFileContents?.gunzip()
      ?? wrapper.fileWrappers?[BundleWrapperKey.studyLog]?.regularFileContents
    guard let logData = maybeData,
      let logText = String(data: logData, encoding: .utf8),
      let studyLog = StudyLog(logText) else {
      return StudyLog()
    }
    return studyLog
  }

  func compressedSnippetsFileWrapper() throws -> FileWrapper {
    let text = try noteArchiveQueue.sync { () -> String in
      try noteArchive.archivePageManifestVersion(timestamp: Date())
      return noteArchive.textSerialized()
    }
    guard let compressed = text.data(using: .utf8)!.gzip() else {
      throw error(for: .couldNotCompressArchive)
    }
    let compressedWrapper = FileWrapper(regularFileWithContents: compressed)
    compressedWrapper.preferredFilename = BundleWrapperKey.compressedSnippets
    return compressedWrapper
  }

  /// Removes unneeded data file wrappers from `directoryWrapper`
  func purgeUnneededWrappers(from directoryWrapper: FileWrapper) {
    precondition(directoryWrapper.isDirectory)
    let unneededKeys = Set(directoryWrapper.fileWrappers!.keys)
      .subtracting([BundleWrapperKey.compressedStudyLog, BundleWrapperKey.compressedSnippets, BundleWrapperKey.assets])
    for key in unneededKeys {
      directoryWrapper.removeFileWrapper(directoryWrapper.fileWrappers![key]!)
    }
  }
}

/// Making NSErrors...
public extension NoteDocumentStorage {
  static let errorDomain = "NoteArchiveDocument"

  enum ErrorCode: String, CaseIterable {
    case couldNotCompressArchive = "Could not compress text.snippets"
    case couldNotCompressStudyLog = "Could not compress study.log"
    case textSnippetsDeserializeError = "Unexpected error deserializing text.snippets"
    case unexpectedContentType = "Unexpected file content type"
  }

  /// Constructs an NSError based upon the the `ErrorCode` string value & index.
  func error(for code: ErrorCode) -> NSError {
    let index = ErrorCode.allCases.firstIndex(of: code)!
    return NSError(
      domain: NoteDocumentStorage.errorDomain,
      code: index,
      userInfo: [NSLocalizedDescriptionKey: code.rawValue]
    )
  }

  /// Constructs an NSError that wraps another arbitrary error.
  func wrapError(code: ErrorCode, innerError: Error) -> NSError {
    let index = ErrorCode.allCases.firstIndex(of: code)!
    return NSError(
      domain: NoteDocumentStorage.errorDomain,
      code: index,
      userInfo: [
        NSLocalizedDescriptionKey: code.rawValue,
        "innerError": innerError,
      ]
    )
  }
}

// MARK: - Study sessions

public extension NoteDocumentStorage {
  func recordStudyEntry(_ entry: StudyLog.Entry) throws {
    studyLog.append(entry)
    invalidateSavedStudyLog()
    notesDidChangeSubject.send()
  }
}

// MARK: - Images

extension NoteDocumentStorage {
  /// Stores asset data into the document.
  /// - parameter data: The asset data to store
  /// - parameter typeHint: A hint about the data type, e.g., "jpeg" -- will be used for the data key
  /// - returns: A key that can be used to get the data later.
  public func storeAssetData(_ data: Data, key: String) -> String {
    let assetsWrapper = assetsFileWrapper
    if assetsWrapper.fileWrappers![key] == nil {
      let imageFileWrapper = FileWrapper(regularFileWithContents: data)
      imageFileWrapper.preferredFilename = key
      assetsWrapper.addFileWrapper(imageFileWrapper)
    }
    return "\(BundleWrapperKey.assets)/\(key)"
  }
}

internal extension NoteProperties {
  func asNoteMetadata() -> Note.Metadata {
    Note.Metadata(
      timestamp: timestamp,
      hashtags: hashtags,
      title: title,
      containsText: sha1Digest != nil
    )
  }
}
