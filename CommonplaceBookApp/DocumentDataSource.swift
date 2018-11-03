// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject, ListAdapterDataSourceWithAdapter {
  public init(index: DocumentPropertiesIndex, stylesheet: Stylesheet) {
    self.index = index
    self.stylesheet = stylesheet
    super.init()
    index.addDataSource(self)
  }

  deinit {
    index.removeDataSource(self)
  }

  private let index: DocumentPropertiesIndex
  private let stylesheet: Stylesheet
  public weak var adapter: ListAdapter?
  public var filteredHashtag: String? {
    didSet {
      adapter?.performUpdates(animated: true)
    }
  }

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return index.properties.values
      .filter { !$0.value.placeholder }
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.value.hashtags.contains(hashtag)
      }
      .sorted(
        by: { $0.value.fileMetadata.contentChangeDate > $1.value.fileMetadata.contentChangeDate }
      )
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
