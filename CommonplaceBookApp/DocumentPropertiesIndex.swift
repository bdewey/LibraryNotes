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

  /// Properties in the index changed.
  func documentPropertiesIndexDidChange(_ index: DocumentPropertiesIndex)
}

private struct DataSourceWrapper {
  init(_ value: ListAdapterDataSourceWithAdapter) { self.value = value }
  weak var value: ListAdapterDataSourceWithAdapter?
}

/// Maintains the mapping of document name to document properties.
public final class DocumentPropertiesIndex: NSObject {

  /// Designated initializer.
  ///
  /// @param parsingrules The rules used to parse the text content of documents.
  public init(parsingRules: ParsingRules) {
    self.parsingRules = parsingRules
  }

  /// Delegate.
  public weak var delegate: DocumentPropertiesIndexDelegate?

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  /// The mapping between document names and document properties.
  public internal(set) var properties: [URL: DocumentPropertiesListDiffable] = [:] {
    didSet {
      performUpdates()
      delegate?.documentPropertiesIndexDidChange(self)
    }
  }

  /// All IGListKit data sources that are currently displaying data based on the index.
  /// These data sources get notified of changes to properties.
  private var dataSources: [DataSourceWrapper] = []

  /// Registers an IGListKit list adapter with this index.
  ///
  /// @param dataSource The adapter to register. It will get notifications of changes.
  public func addDataSource(_ dataSource: ListAdapterDataSourceWithAdapter) {
    dataSources.append(DataSourceWrapper(dataSource))
  }

  /// Removes the list adapter. It will no longer get notifications of changes.
  ///
  /// @param The adapter to unregister.
  public func removeDataSource(_ dataSource: ListAdapterDataSourceWithAdapter) {
    guard let index = dataSources.firstIndex(where: { $0.value === dataSource }) else { return }
    dataSources.remove(at: index)
  }

  /// Tell all registered list adapters to perform updates.
  private func performUpdates() {
    for dataSource in dataSources {
      dataSource.value?.adapter?.performUpdates(animated: true)
    }
  }

  /// Deletes a document and its properties.
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
