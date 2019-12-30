// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

/// Abstract interface for something that can store notes, challenges, and study logs, and can also generate study sessions.
public protocol NoteStorage: TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  func changeTextContents(for pageIdentifier: String, to text: String)

  /// Gets data contained in a file wrapper
  /// - parameter fileWrapperKey: A path to a named file wrapper. E.g., "assets/image.png"
  /// - returns: The data contained in that wrapper if it exists, nil otherwise.
  func data<S: StringProtocol>(for fileWrapperKey: S) -> Data?
  func addObserver(_ observer: NoteArchiveDocumentObserver)
  func removeObserver(_ observer: NoteArchiveDocumentObserver)
  func currentTextContents(for pageIdentifier: String) throws -> String

  /// Computes a studySession for the relevant pages in the notebook.
  /// - parameter filter: An optional filter closure to determine if the page's challenges should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining challenge eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  func studySession(
    filter: ((String, PageProperties) -> Bool)?,
    date: Date,
    completion: @escaping (StudySession) -> Void
  )

  /// Blocking function that gets the study session. Safe to call from background threads. Part of the protocol to make testing easier.
  func synchronousStudySession(
    filter: ((String, PageProperties) -> Bool)?,
    date: Date
  ) -> StudySession

  /// All hashtags used across all pages, sorted.
  var hashtags: [String] { get }
  func deletePage(pageIdentifier: String) throws

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date)
  var pageProperties: [String: PageProperties] { get }
  var parsingRules: ParsingRules { get }

  /// Adds a renderer tthat knows how to render images using assets from this document
  /// - parameter renderers: The collection of render functions
  func addImageRenderer(to renderers: inout [NodeType: RenderedMarkdown.RenderFunction])

  /// Stores asset data into the document.
  /// - parameter data: The asset data to store
  /// - parameter typeHint: A hint about the data type, e.g., "jpeg" -- will be used for the data key
  /// - returns: A key that can be used to get the data later.
  func storeAssetData(_ data: Data, typeHint: String) -> String
  func changePageProperties(for pageIdentifier: String, to pageProperties: PageProperties)
  func insertPageProperties(_ pageProperties: PageProperties) -> String
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

public protocol NoteArchiveDocumentObserver: AnyObject {
  func noteArchiveDocument(
    _ document: NoteStorage,
    didUpdatePageProperties properties: [String: PageProperties]
  )
}