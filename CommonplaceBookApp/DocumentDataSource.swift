// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(notebook: Notebook, stylesheet: Stylesheet) {
    self.notebook = notebook
    self.stylesheet = stylesheet
    super.init()
    notebook.addListener(self)
    updateCardsPerDocument()
  }

  deinit {
    notebook.removeListener(self)
  }

  public let notebook: Notebook
  private let stylesheet: Stylesheet
  public var filteredHashtag: String?
  public var cardsPerDocument = [String: Int]()

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return propertiesFilteredByHashtag
      // give IGLitstKit its own copy of the model objects to guard against mutations
      .map {
        PagePropertiesListDiffable(
          $0,
          cardCount: cardsPerDocument[$0.fileMetadata.fileName, default: 0]
        )
      }
      .sorted(
        by: { $0.value.fileMetadata.contentChangeDate > $1.value.fileMetadata.contentChangeDate }
      )
  }

  private var propertiesFilteredByHashtag: [PageProperties] {
    return notebook.pageProperties.values
      // remove placeholders
      .filter { $0.tag != .placeholder }
      // Convert to just a DocumentProperties
      .map { $0.value }
      // only show things with the right hashtag
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.hashtags.contains(hashtag)
      }
  }

  public func studySession(metadata: NotebookStudyMetadata) -> StudySession {
    // TODO: Should be a way to associate ParsingRules with each document
    return propertiesFilteredByHashtag.map { (diffableProperties) -> StudySession in
      let documentMetadata = metadata[diffableProperties.fileMetadata.fileName, default: [:]]
      return documentMetadata.studySession(
        from: diffableProperties.cardTemplates.cards,
        limit: 500,
        properties: CardDocumentProperties(documentName: diffableProperties.fileMetadata.fileName, attributionMarkdown: diffableProperties.title, parsingRules: LanguageDeck.parsingRules)
      )
    }
    .reduce(into: StudySession(), { $0 += $1 })
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

extension DocumentDataSource: NotebookChangeListener {
  public func notebook(_ notebook: Notebook, didChange key: Notebook.Key) {
    updateCardsPerDocument()
  }
}
