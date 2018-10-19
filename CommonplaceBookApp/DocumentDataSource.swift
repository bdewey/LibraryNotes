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
  public func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    let models = items
      .map { FileMetadataWrapper(metadataItem: $0) }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded()
      DocumentProperties.loadProperties(from: fileMetadata) { (result) in
        switch result {
        case .success(let properties):
          self.properties[properties.fileMetadata.fileURL] = DocumentPropertiesListDiffable(properties)
          DDLogInfo("Successfully loaded: " + properties.title)
        case .failure(let error):
          self.properties[fileMetadata.value.fileURL] = nil
          DDLogError("Error loading properties: \(error)")
        }
      }
    }
    adapter?.performUpdates(animated: true)
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
