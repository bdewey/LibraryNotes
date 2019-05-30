// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import IGListKit

/// ListKit data source for the pages in a NoteBundleDocument
public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(
    notebook: NoteArchiveDocument,
    stylesheet: Stylesheet
  ) {
    self.notebook = notebook
    self.stylesheet = stylesheet
    super.init()
    notebook.addObserver(self)
    updateCardsPerDocument()
  }

  deinit {
    notebook.removeObserver(self)
  }

  public let notebook: NoteArchiveDocument
  private let stylesheet: Stylesheet
  public var filteredHashtag: String?
  public var cardsPerDocument = [String: Int]()

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    let objects = propertiesFilteredByHashtag
      // give IGLitstKit its own copy of the model objects to guard against mutations
      .compactMap { tuple -> NoteBundlePagePropertiesListDiffable? in
        return NoteBundlePagePropertiesListDiffable(
          pageKey: tuple.key,
          properties: tuple.value,
          cardCount: cardsPerDocument[tuple.key, default: 0]
        )
      }
      .sorted(
        by: { $0.properties.timestamp > $1.properties.timestamp }
      )
    return objects
  }

  private var propertiesFilteredByHashtag: [String: PageProperties] {
    return notebook.pageProperties
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.value.hashtags.contains(hashtag)
      }
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(
      notebook: notebook,
      stylesheet: stylesheet
    )
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }

  fileprivate func updateCardsPerDocument() {
    let studySession = notebook.studySession()
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

extension DocumentDataSource: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    updateCardsPerDocument()
  }
}
