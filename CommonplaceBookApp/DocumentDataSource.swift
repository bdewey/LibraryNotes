// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(index: DocumentPropertiesIndex, stylesheet: Stylesheet) {
    self.index = index
    self.stylesheet = stylesheet
  }

  public let index: DocumentPropertiesIndex
  private let stylesheet: Stylesheet
  public var filteredHashtag: String?

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return index.properties.values
      // remove placeholders
      .filter { !$0.value.placeholder }
      // only show things with the right hashtag
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.value.hashtags.contains(hashtag)
      }
      // sort by change time
      .sorted(
        by: { $0.value.fileMetadata.contentChangeDate > $1.value.fileMetadata.contentChangeDate }
      )
      // give IGLitstKit its own copy of the model objects to guard against mutations
      .map { DocumentPropertiesListDiffable($0.value) }
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
