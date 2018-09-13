// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject {
  private var models: [FileMetadata] = []
  public weak var adapter: ListAdapter?

  public func deleteMetadata(_ fileMetadata: FileMetadata) {
    if let index = models.firstIndex(where: { $0 == fileMetadata }) {
      try? FileManager.default.removeItem(at: fileMetadata.fileURL)
      models.remove(at: index)
      adapter?.performUpdates(animated: true)
    }
  }
}

extension DocumentDataSource: MetadataQueryDelegate {
  public func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    models = items
      .map { FileMetadata(metadataItem: $0) }
      .sorted(by: { $0.displayName < $1.displayName })
    adapter?.performUpdates(animated: true)
  }
}

extension DocumentDataSource: ListAdapterDataSource {
  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return models
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(dataSource: self)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}
