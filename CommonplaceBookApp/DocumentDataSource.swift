// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import Foundation
import IGListKit

public final class DocumentDataSource: NSObject {

  public init(stylesheet: Stylesheet) {
    self.stylesheet = stylesheet
  }

  private let stylesheet: Stylesheet
  public weak var adapter: ListAdapter?
  private var properties: [URL: DocumentPropertiesListDiffable] = [:]

  public func deleteDocument(_ properties: DocumentPropertiesListDiffable) {
    let url = properties.value.fileMetadata.fileURL
    try? FileManager.default.removeItem(at: url)
    self.properties[url] = nil
    adapter?.performUpdates(animated: true)
  }
}

extension DocumentDataSource: MetadataQueryDelegate {
  fileprivate func updateProperties(for fileMetadata: FileMetadataWrapper) {
    let urlKey = fileMetadata.value.fileURL
    if properties[urlKey]?.value.fileMetadata.contentChangeDate ==
      fileMetadata.value.contentChangeDate {
      return
    }
    DocumentProperties.loadProperties(from: fileMetadata) { (result) in
      switch result {
      case .success(let properties):
        self.properties[urlKey] = DocumentPropertiesListDiffable(properties)
        DDLogInfo("Successfully loaded: " + properties.title)
        self.adapter?.performUpdates(animated: true)
      case .failure(let error):
        self.properties[urlKey] = nil
        DDLogError("Error loading properties: \(error)")
      }
    }
  }

  public func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    let models = items
      .map { FileMetadataWrapper(metadataItem: $0) }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded()
      updateProperties(for: fileMetadata)
    }
  }
}

extension DocumentDataSource: ListAdapterDataSource {
  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    return properties.values.sorted(by: { $0.value.fileMetadata.displayName < $1.value.fileMetadata.displayName })
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(dataSource: self, stylesheet: stylesheet)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}
