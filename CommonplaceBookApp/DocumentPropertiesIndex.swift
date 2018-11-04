// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import Foundation
import IGListKit
import MiniMarkdown

/// A specialization of ListAdapterDataSource that contains a weak reference back to
/// an adapter that uses this data source.
public protocol ListAdapterDataSourceWithAdapter: ListAdapterDataSource {
  var adapter: ListAdapter? { get }
}

public protocol DocumentPropertiesIndexDelegate: class {
  func documentPropertiesIndexDidChange(_ index: DocumentPropertiesIndex)
}

private struct DataSourceWrapper {
  init(_ value: ListAdapterDataSourceWithAdapter) { self.value = value }
  weak var value: ListAdapterDataSourceWithAdapter?
}

public final class DocumentPropertiesIndex: NSObject {

  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  public weak var delegate: DocumentPropertiesIndexDelegate?
  public let parsingRules: ParsingRules
  public var properties: [URL: DocumentPropertiesListDiffable] = [:] {
    didSet {
      performUpdates()
      delegate?.documentPropertiesIndexDidChange(self)
    }
  }

  private var dataSources: [DataSourceWrapper] = []

  public func addDataSource(_ dataSource: ListAdapterDataSourceWithAdapter) {
    dataSources.append(DataSourceWrapper(dataSource))
  }

  public func removeDataSource(_ dataSource: ListAdapterDataSourceWithAdapter) {
    guard let index = dataSources.firstIndex(where: { $0.value === dataSource }) else { return }
    dataSources.remove(at: index)
  }

  private func performUpdates() {
    for dataSource in dataSources {
      dataSource.value?.adapter?.performUpdates(animated: true)
    }
  }

  public func deleteDocument(_ properties: DocumentPropertiesListDiffable) {
    let url = properties.value.fileMetadata.fileURL
    try? FileManager.default.removeItem(at: url)
    self.properties[url] = nil
    performUpdates()
  }
}

extension DocumentPropertiesIndex: MetadataQueryDelegate {
  fileprivate func updateProperties(for fileMetadata: FileMetadataWrapper) {
    let urlKey = fileMetadata.value.fileURL
    if properties[urlKey]?.value.fileMetadata.contentChangeDate ==
      fileMetadata.value.contentChangeDate {
      return
    }
    // Put an entry in the properties dictionary that contains the current
    // contentChangeDate. We'll replace it with something with the actual extracted
    // properties in the completion block below. This is needed to prevent multiple
    // loads for the same content.
    properties[urlKey] = DocumentPropertiesListDiffable(fileMetadata.value)
    DocumentProperties.loadProperties(
      from: fileMetadata,
      parsingRules: parsingRules
    ) { (result) in
      switch result {
      case .success(let properties):
        self.properties[urlKey] = DocumentPropertiesListDiffable(properties)
        DDLogInfo("Successfully loaded: " + properties.title)
        self.performUpdates()
      case .failure(let error):
        self.properties[urlKey] = nil
        DDLogError("Error loading properties: \(error)")
      }
    }
  }

  public func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    let models = items
      .map { FileMetadataWrapper(metadataItem: $0) }
      .filter { $0.value.fileURL.lastPathComponent != DocumentPropertiesIndexDocument.name }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded()
      updateProperties(for: fileMetadata)
    }
  }
}
