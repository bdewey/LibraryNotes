// Copyright © 2019 Brian's Brain. All rights reserved.

import FlashcardKit
import UIKit

public protocol StudyMetadataDocumentObserver: AnyObject {
  func studyMetadataDocumentDidLoad(_ document: StudyMetadataDocument)
}

/// Holds all of the information needed to conduct study sessions.
public final class StudyMetadataDocument: UIDocument {

  public enum Error: Swift.Error {
    case documentKeyNotFound
  }

  /// All challenge templates across all pages.
  public private(set) var challengeTemplates = ChallengeTemplateCollection()

  public private(set) var log = [ChangeRecord]()

  /// All things watching the document lifecycle.
  private var observers: [WeakObserver] = []

  /// Inserts a ChallengeTemplate into the document.
  /// - returns: The key that can be used to retrieve this template from `challengeTemplates`
  public func insert(_ challengeTemplate: ChallengeTemplate) throws -> String {
    assert(Thread.isMainThread)
    let (key, didChange) = try challengeTemplates.insert(challengeTemplate)
    if didChange {
      updateChangeCount(.done)
      log.append(ChangeRecord(timestamp: Date(), change: .addedChallengeTemplate(id: key)))
    }
    return key
  }

  /// Loads document data.
  /// The document is a bundle of different data streams.
  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard let directory = contents as? FileWrapper else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: nil)
    }
    challengeTemplates = try directory.loadChallengeTemplateCollection()
    log = try directory.loadLog()
    for wrapper in observers {
      wrapper.observer?.studyMetadataDocumentDidLoad(self)
    }
  }

  /// Generates a bundle containing all of the current data.
  public override func contents(forType typeName: String) throws -> Any {
    let logString = log.map { $0.description }.joined(separator: "\n")
    let logWrapper = FileWrapper(regularFileWithContents: logString.data(using: .utf8)!)
    return FileWrapper(
      directoryWithFileWrappers: [
        BundleKey.challengeTemplates: try challengeTemplates.fileWrapper(),
        BundleKey.log: logWrapper,
      ]
    )
  }
}

extension StudyMetadataDocument: Observable {
  public func addObserver(_ observer: StudyMetadataDocumentObserver) {
    observers.append(WeakObserver(observer))
  }

  public func removeObserver(_ observer: StudyMetadataDocumentObserver) {
    observers.removeAll { wrapped -> Bool in
      wrapped.observer === observer
    }
  }
}

private extension String {
  func removingPrefix(_ prefix: String) -> Substring? {
    guard hasPrefix(prefix) else { return nil }
    return suffix(from: index(startIndex, offsetBy: prefix.count))
  }
}

public extension StudyMetadataDocument {
  enum Change: LosslessStringConvertible {

    /// We added a template to the document.
    case addedChallengeTemplate(id: String)

    /// Decode a change from a string.
    public init?(_ description: String) {
      if let id = description.removingPrefix("add template ") {
        self = .addedChallengeTemplate(id: String(id))
      } else {
        return nil
      }
    }

    /// Turn a change into a string.
    public var description: String {
      switch self {
      case .addedChallengeTemplate(let id):
        return "add template " + id
      }
    }
  }

  struct ChangeRecord: LosslessStringConvertible {
    let timestamp: Date
    let change: Change

    public init(timestamp: Date, change: Change) {
      self.timestamp = timestamp
      self.change = change
    }

    public init?(_ description: String) {
      guard let firstWhitespace = description.firstIndex(of: " ") else {
        return nil
      }
      let dateSlice = description[description.startIndex ..< firstWhitespace]
      let skippingWhitespace = description.index(after: firstWhitespace)
      let changeSlice = description[skippingWhitespace...]
      guard let timestamp = ISO8601DateFormatter().date(from: String(dateSlice)),
        let change = Change(String(changeSlice)) else {
          return nil
      }
      self.timestamp = timestamp
      self.change = change
    }

    public var description: String {
      return ISO8601DateFormatter().string(from: timestamp) + " " + change.description
    }
  }
}

/// The names of the different streams inside our bundle.
private enum BundleKey {
  static let challengeTemplates = "challenge-templates.json"
  static let log = "change.log"
}

/// Loading properties.
private extension FileWrapper {
  func loadChallengeTemplateCollection() throws -> ChallengeTemplateCollection {
    guard
      let wrapper = fileWrappers?[BundleKey.challengeTemplates],
      let data = wrapper.regularFileContents
      else {
        throw StudyMetadataDocument.Error.documentKeyNotFound
    }
    return try JSONDecoder().decode(ChallengeTemplateCollection.self, from: data)
  }

  func loadLog() throws -> [StudyMetadataDocument.ChangeRecord] {
    guard let wrapper = fileWrappers?[BundleKey.log],
      let data = wrapper.regularFileContents,
      let str = String(data: data, encoding: .utf8) else {
        throw StudyMetadataDocument.Error.documentKeyNotFound
    }
    return str.split(separator: "\n").compactMap { StudyMetadataDocument.ChangeRecord(String($0)) }
  }
}

private extension ChallengeTemplateCollection {
  func fileWrapper() throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return FileWrapper(regularFileWithContents: data)
  }
}

private struct WeakObserver {
  weak var observer: StudyMetadataDocumentObserver?
  init(_ observer: StudyMetadataDocumentObserver) { self.observer = observer }
}
