// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import IGListKit
import MiniMarkdown
import UIKit

public protocol NoteArchiveDocumentObserver: AnyObject {
  func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  )
}

extension ListAdapter: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    performUpdates(animated: true)
  }
}

public final class NoteArchiveDocument: UIDocument {
  public init(fileURL url: URL, parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
    self.noteArchive = NoteArchive(parsingRules: parsingRules)
    super.init(fileURL: url)
  }

  /// How to parse Markdown in the snippets
  private let parsingRules: ParsingRules

  /// Top-level FileWrapper for our contents
  private var topLevelFileWrapper: FileWrapper?

  /// The actual document contents.
  internal var noteArchive: NoteArchive

  /// Protects noteArchive.
  internal let noteArchiveQueue = DispatchQueue(label: "org.brians-brain.note-archive-document")

  private let challengeTemplateCache = NSCache<NSString, ChallengeTemplate>()

  /// The observers.
  private var observers: [WeakObserver] = []

  /// Accessor for the page properties.
  public var pageProperties: [String: PageProperties] {
    return noteArchiveQueue.sync {
      noteArchive.pageProperties
    }
  }

  public func deletePage(pageIdentifier: String) {
    assertionFailure("Not implemented")
  }

  /// Deserialize `noteArchive` from `contents`
  /// - precondition: `contents` is a directory FileWrapper with a "text.snippets" regular file
  /// - throws: NSError in the NoteArchiveDocument domain on any error
  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard let wrapper = contents as? FileWrapper, wrapper.isDirectory else {
      throw error(for: .unexpectedContentType)
    }
    topLevelFileWrapper = wrapper
    guard
      let data = wrapper.fileWrappers?["text.snippets"]?.regularFileContents,
      let text = String(data: data, encoding: .utf8) else {
        // Is this an error? Or expected for a new document?
        return
    }
    do {
      let pageProperties = try noteArchiveQueue.sync { () -> [String: PageProperties] in
        noteArchive = try NoteArchive(parsingRules: parsingRules, textSerialization: text)
        return noteArchive.pageProperties
      }
      DDLogInfo("Loaded \(pageProperties.count) pages")
      notifyObservers(of: pageProperties)
    } catch {
      throw wrapError(code: .textSnippetsDeserializeError, innerError: error)
    }
  }

  /// Serialize `noteArchive` to `topLevelFileWrapper` and return `topLevelFileWrapper` for saving
  public override func contents(forType typeName: String) throws -> Any {
    let topLevelFileWrapper = self.topLevelFileWrapper
      ?? FileWrapper(directoryWithFileWrappers: [:])
    precondition(topLevelFileWrapper.isDirectory)
    if topLevelFileWrapper.fileWrappers!["text.snippets"] == nil {
      topLevelFileWrapper.addFileWrapper(textSnippetsFileWrapper())
    }
    self.topLevelFileWrapper = topLevelFileWrapper
    return topLevelFileWrapper
  }

  /// Lets the UIDocument infrastructure know we have content to save, and also
  /// discards our in-memory representation of the snippet file wrapper.
  internal func invalidateSavedSnippets() {
    if let topLevelFileWrapper = topLevelFileWrapper,
      let archiveWrapper = topLevelFileWrapper.fileWrappers!["text.snippets"] {
      topLevelFileWrapper.removeFileWrapper(archiveWrapper)
    }
    updateChangeCount(.done)
  }
}

/// Observing.
public extension NoteArchiveDocument {
  private struct WeakObserver {
    weak var observer: NoteArchiveDocumentObserver?
    init(_ observer: NoteArchiveDocumentObserver) { self.observer = observer }
  }

  func addObserver(_ observer: NoteArchiveDocumentObserver) {
    assert(Thread.isMainThread)
    observers.append(WeakObserver(observer))
  }

  func removeObserver(_ observer: NoteArchiveDocumentObserver) {
    assert(Thread.isMainThread)
    observers.removeAll(where: { $0.observer === observer })
  }

  internal func notifyObservers(of pageProperties: [String: PageProperties]) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async {
        self.notifyObservers(of: pageProperties)
      }
      return
    }
    for observerWrapper in observers {
      observerWrapper.observer?.noteArchiveDocument(self, didUpdatePageProperties: pageProperties)
    }
  }
}

private extension NoteArchiveDocument {
  /// Returns a FileWrapper containing the serialized text snippets
  func textSnippetsFileWrapper() -> FileWrapper {
    let text = noteArchiveQueue.sync {
      noteArchive.textSerialized()
    }
    let fileWrapper = FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    fileWrapper.preferredFilename = "text.snippets"
    return fileWrapper
  }
}

/// Making NSErrors...
public extension NoteArchiveDocument {
  static let errorDomain = "NoteArchiveDocument"

  enum ErrorCode: String, CaseIterable {
    case textSnippetsDeserializeError = "Unexpected error deserializing text.snippets"
    case unexpectedContentType = "Unexpected file content type"
  }

  /// Constructs an NSError based upon the the `ErrorCode` string value & index.
  func error(for code: ErrorCode) -> NSError {
    let index = ErrorCode.allCases.firstIndex(of: code)!
    return NSError(
      domain: NoteArchiveDocument.errorDomain,
      code: index,
      userInfo: [NSLocalizedDescriptionKey: code.rawValue]
    )
  }

  /// Constructs an NSError that wraps another arbitrary error.
  func wrapError(code: ErrorCode, innerError: Error) -> NSError {
    let index = ErrorCode.allCases.firstIndex(of: code)!
    return NSError(
      domain: NoteArchiveDocument.errorDomain,
      code: index,
      userInfo: [
        NSLocalizedDescriptionKey: code.rawValue,
        "innerError": innerError,
      ]
    )
  }
}

// MARK: - Study sessions
public extension NoteArchiveDocument {
  func studySession(
    filter: ((String, PageProperties) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    return noteArchiveQueue.sync {
      return noteArchive.pageProperties
        .filter { filter($0.key, $0.value) }
        .map { (name, reviewProperties) -> StudySession in
          let challengeTemplates = reviewProperties.cardTemplates
            .compactMap { keyString -> ChallengeTemplate? in
              guard let key = ChallengeTemplateArchiveKey(keyString) else {
                DDLogError("Expected a challenge key: \(keyString)")
                return nil
              }
              if let cachedTemplate = challengeTemplateCache.object(forKey: keyString as NSString) {
                return cachedTemplate
              }
              do {
                let template = try noteArchive.challengeTemplate(for: key)
                challengeTemplateCache.setObject(template, forKey: keyString as NSString)
                return template
              } catch {
                DDLogError("Unexpected error getting challenge template: \(error)")
                return nil
              }
            }
          // TODO: Filter down to eligible cards
          let eligibleCards = challengeTemplates.cards
          return StudySession(
            eligibleCards,
            properties: CardDocumentProperties(
              documentName: name,
              attributionMarkdown: reviewProperties.title,
              parsingRules: self.parsingRules
            )
          )
        }
        .reduce(into: StudySession(), { $0 += $1 })
    }
  }

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date = Date()) {
    assertionFailure("Not implemented")
  }
}
