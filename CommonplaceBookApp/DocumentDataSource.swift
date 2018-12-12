// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(index: Notebook, stylesheet: Stylesheet) {
    self.index = index
    self.stylesheet = stylesheet
  }

  public let index: Notebook
  private let stylesheet: Stylesheet
  public var filteredHashtag: String?

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return propertiesFilteredByHashtag
      .sorted(
        by: { $0.fileMetadata.contentChangeDate > $1.fileMetadata.contentChangeDate }
      )
      // give IGLitstKit its own copy of the model objects to guard against mutations
      // TODO: Why do I store ListDiffable things if I just make new ListDiffable things?
      .map { DocumentPropertiesListDiffable($0) }
  }

  private var propertiesFilteredByHashtag: [PageProperties] {
    return index.pages.values
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
        documentName: diffableProperties.fileMetadata.fileName,
        parsingRules: LanguageDeck.parsingRules
      )
    }
    .reduce(into: StudySession(), { $0 += $1 })
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(index: index, stylesheet: stylesheet)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}
