// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import MiniMarkdown
import TextBundleKit

/// Contains all of the data to:
///
/// - Know what information the person wants to review (ChallengeTemplateCollection)
/// - How the templates are grouped into named pages (PageProperties)
/// - A history of changes (adding & removing content) plus review history (the log)
/// - Plus an method to construct study sessions from the contents of the NoteBundle, and update
///   NoteBundle state as a result of studying. (Phew!)
public struct NoteBundle {

  /// Default initializer; creates an empty NoteBundle.
  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  /// Rules used to parse challenge templates.
  public let parsingRules: ParsingRules

  /// All challenge templates in the bundle.
  internal var challengeTemplates = ChallengeTemplateCollection()

  /// Log of all changes to the NoteBundle.
  internal var log: [ChangeRecord] = []

  /// Page properties, indexed by page name.
  public internal(set) var pageProperties: [String: NoteBundlePageProperties] = [:]
}

/// Data serialization for non-primitive types in the NoteBundle
internal extension NoteBundle {
  func logData() -> Data {
    let logString = log.map { $0.description }.joined(separator: "\n")
    return logString.data(using: .utf8)!
  }

  static func makeLog(from data: Data) -> [ChangeRecord] {
    let str = String(data: data, encoding: .utf8)!
    return str.split(separator: "\n").compactMap { NoteBundle.ChangeRecord(String($0)) }
  }

  func pagesData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    let pageData = try encoder.encode(pageProperties)
    return pageData
  }

  static func makePages(from data: Data) throws -> [String: NoteBundlePageProperties] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([String: NoteBundlePageProperties].self, from: data)
  }
}

/// FileWrapper serialization.
public extension NoteBundle {
  enum FileWrapperSerializationError: Error {
    case noDataForKey(String)
  }

  /// The names of the different streams inside our bundle.
  private enum BundleKey {
    static let challengeTemplates = "challenge-templates.tdat"
    static let log = "change.log"
    static let pages = "pages.json"
  }

  /// Construct a NoteBundle from the contents of a FileWrapper
  /// - precondition: FileWrapper is a directory file wrapper.
  init(parsingRules: ParsingRules, fileWrapper: FileWrapper) throws {
    self.parsingRules = parsingRules
    self.challengeTemplates = try ChallengeTemplateCollection(
      parsingRules: parsingRules,
      data: try fileWrapper.data(from: BundleKey.challengeTemplates)
    )
    self.log = NoteBundle.makeLog(from: try fileWrapper.data(from: BundleKey.log))
    self.pageProperties = try NoteBundle.makePages(
      from: try fileWrapper.data(from: BundleKey.pages)
    )
  }

  /// Creates a directory file wrapper from a NoteBundle.
  func fileWrapper() throws -> FileWrapper {
    return FileWrapper(
      directoryWithFileWrappers: [
        BundleKey.challengeTemplates: FileWrapper(
          regularFileWithContents: challengeTemplates.data()
        ),
        BundleKey.log: FileWrapper(regularFileWithContents: logData()),
        BundleKey.pages: FileWrapper(regularFileWithContents: try pagesData()),
      ]
    )
  }
}

private extension FileWrapper {
  func data(from key: String) throws -> Data {
    guard let wrapper = fileWrappers?[key], let data = wrapper.regularFileContents else {
      throw NoteBundle.FileWrapperSerializationError.noDataForKey(key)
    }
    return data
  }
}
