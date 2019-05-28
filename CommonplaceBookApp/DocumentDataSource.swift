// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import IGListKit

/// ListKit data source for the pages in a NoteBundleDocument
public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(
    notebook: NoteBundleDocument,
    fileMetadataProvider: FileMetadataProvider,
    stylesheet: Stylesheet
  ) {
    self.notebook = notebook
    self.fileMetadataProvider = fileMetadataProvider
    self.stylesheet = stylesheet
    super.init()
    notebook.addObserver(self)
    updateCardsPerDocument()
  }

  deinit {
    notebook.removeObserver(self)
  }

  public let notebook: NoteBundleDocument
  public let fileMetadataProvider: FileMetadataProvider
  private let stylesheet: Stylesheet
  public var filteredHashtag: String?
  public var cardsPerDocument = [String: Int]()

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return propertiesFilteredByHashtag
      // give IGLitstKit its own copy of the model objects to guard against mutations
      .compactMap { tuple -> NoteBundlePagePropertiesListDiffable? in
        guard let fileMetadata = self.fileMetadataProvider.fileMetadata.first(where: { $0.fileName == tuple.key }) else {
          return nil
        }
        return NoteBundlePagePropertiesListDiffable(
          fileMetadata: fileMetadata,
          properties: tuple.value,
          cardCount: cardsPerDocument[tuple.key, default: 0]
        )
      }
      .sorted(
        by: { $0.properties.timestamp > $1.properties.timestamp }
      )
  }

  private var propertiesFilteredByHashtag: [String: PageProperties] {
    return notebook.noteBundle.pageProperties
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.value.hashtags.contains(hashtag)
      }
  }

//  public func studySession(metadata: NotebookStudyMetadata) -> StudySession {
//    // TODO: Should be a way to associate ParsingRules with each document
//    return propertiesFilteredByHashtag.map { (keyValue) -> StudySession in
//      let documentMetadata = metadata[keyValue.key, default: [:]]
//      return documentMetadata.studySession(
//        from: keyValue.cardTemplates.cards,
//        limit: 500,
//        properties: CardDocumentProperties(documentName: keyValue.fileMetadata.fileName, attributionMarkdown: keyValue.title, parsingRules: LanguageDeck.parsingRules)
//      )
//    }
//    .reduce(into: StudySession(), { $0 += $1 })
//  }
//
  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(
      notebook: notebook,
      metadataProvider: fileMetadataProvider,
      stylesheet: stylesheet
    )
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }

  fileprivate func updateCardsPerDocument() {
    let studySession = notebook.noteBundle.studySession()
    cardsPerDocument = studySession
      .reduce(into: [String: Int]()) { cardsPerDocument, card in
        cardsPerDocument[card.properties.documentName] = cardsPerDocument[card.properties.documentName, default: 0] + 1
      }
    DDLogInfo(
      "studySession.count = \(studySession.count). " +
        "cardsPerDocument has \(cardsPerDocument.count) entries"
    )
  }
}

extension DocumentDataSource: NoteBundleDocumentObserver {
  public func noteBundleDocument(
    _ document: NoteBundleDocument,
    didChangeToState state: UIDocument.State
  ) {
    // nothing
  }

  public func noteBundleDocumentDidUpdatePages(_ document: NoteBundleDocument) {
    updateCardsPerDocument()
  }
}
