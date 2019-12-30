// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import Foundation
import MiniMarkdown

/// Identifies a page inside NoteStorage.
/// From https://www.swiftbysundell.com/articles/type-safe-identifiers-in-swift/
public struct PageIdentifier: Hashable, RawRepresentable {
  public let rawValue: String

  public init() {
    self.rawValue = UUID().uuidString
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension PageIdentifier: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension PageIdentifier: CustomStringConvertible {
  public var description: String { rawValue }
}

extension PageIdentifier: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// Abstract interface for something that can store notes, challenges, and study logs, and can also generate study sessions.
public protocol NoteStorage: TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  func changeTextContents(for pageIdentifier: PageIdentifier, to text: String)

  /// Gets data contained in a file wrapper
  /// - parameter fileWrapperKey: A path to a named file wrapper. E.g., "assets/image.png"
  /// - returns: The data contained in that wrapper if it exists, nil otherwise.
  func data<S: StringProtocol>(for fileWrapperKey: S) -> Data?
  var pagePropertiesDidChange: PassthroughSubject<[PageIdentifier: PageProperties], Never> { get }
  func currentTextContents(for pageIdentifier: PageIdentifier) throws -> String

  /// Blocking function that gets the study session. Safe to call from background threads. Part of the protocol to make testing easier.
  func synchronousStudySession(
    filter: ((PageIdentifier, PageProperties) -> Bool)?,
    date: Date
  ) -> StudySession

  /// All hashtags used across all pages, sorted.
  var hashtags: [String] { get }
  func deletePage(pageIdentifier: PageIdentifier) throws

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date)
  var pageProperties: [PageIdentifier: PageProperties] { get }
  var parsingRules: ParsingRules { get }

  /// Adds a renderer tthat knows how to render images using assets from this document
  /// - parameter renderers: The collection of render functions
  func addImageRenderer(to renderers: inout [NodeType: RenderedMarkdown.RenderFunction])

  /// Stores asset data into the document.
  /// - parameter data: The asset data to store
  /// - parameter typeHint: A hint about the data type, e.g., "jpeg" -- will be used for the data key
  /// - returns: A key that can be used to get the data later.
  func storeAssetData(_ data: Data, typeHint: String) -> String
  func changePageProperties(for pageIdentifier: PageIdentifier, to pageProperties: PageProperties)
  func insertPageProperties(_ pageProperties: PageProperties) -> PageIdentifier
  func insertChallengeTemplate(_ challengeTemplate: ChallengeTemplate) throws -> ChallengeTemplateArchiveKey
  func challengeTemplate(for keyString: String) -> ChallengeTemplate?
  var studyLog: StudyLog { get }

  func importFileMetadataItems(
    _ items: [FileMetadata],
    from metadataProvider: FileMetadataProvider,
    importDate: Date,
    completion: (() -> Void)?
  )
}

extension NoteStorage {
  /// Computes a studySession for the relevant pages in the notebook.
  /// - parameter filter: An optional filter closure to determine if the page's challenges should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining challenge eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  func studySession(
    filter: ((PageIdentifier, PageProperties) -> Bool)? = nil,
    date: Date = Date(),
    completion: @escaping (StudySession) -> Void
  ) {
    DispatchQueue.global(qos: .default).async {
      let result = self.synchronousStudySession(filter: filter, date: date)
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }
}
