// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import Foundation
import IGListKit
import MiniMarkdown

public protocol DocumentPropertiesIndexDelegate: class {

  /// Properties in the index changed.
  func documentPropertiesIndexDidChange(_ index: DocumentPropertiesIndex)
}

/// Maintains the mapping of document name to document properties.
public final class DocumentPropertiesIndex: NSObject {

  /// Designated initializer.
  ///
  /// - parameter containerURL: The URL of the directory that contains all of the indexed
  ///                           documents.
  /// - parameter parsingrules: The rules used to parse the text content of documents.
  public init(containerURL: URL, parsingRules: ParsingRules) {
    self.containerURL = containerURL
    self.parsingRules = parsingRules
  }

  /// Delegate.
  public weak var delegate: DocumentPropertiesIndexDelegate?

  /// The URL of the directory that contains all of the indexed documents.
  public let containerURL: URL

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  /// The mapping between document names and document properties.
  public internal(set) var properties: [String: DocumentPropertiesListDiffable] = [:] {
    didSet {
      performUpdates()
      delegate?.documentPropertiesIndexDidChange(self)
    }
  }

  /// All IGListKit data sources that are currently displaying data based on the index.
  /// These data sources get notified of changes to properties.
  private var adapters: [WeakWrapper<ListAdapter>] = []

  /// Registers an IGListKit list adapter with this index.
  ///
  /// - parameter adapter: The adapter to register. It will get notifications of changes.
  public func addAdapter(_ adapter: ListAdapter) {
    adapters.append(WeakWrapper(adapter))
  }

  /// Removes the list adapter. It will no longer get notifications of changes.
  ///
  /// - parameter adapter: The adapter to unregister.
  public func removeAdapter(_ adapter: ListAdapter) {
    guard let index = adapters.firstIndex(where: { $0.value === adapter }) else { return }
    adapters.remove(at: index)
  }

  /// Tell all registered list adapters to perform updates.
  private func performUpdates() {
    for adapter in adapters {
      adapter.value?.performUpdates(animated: true)
    }
  }

  /// Deletes a document and its properties.
  public func deleteDocument(_ properties: DocumentPropertiesListDiffable) {
    let name = properties.value.fileMetadata.fileName
    try? FileManager.default.removeItem(at: containerURL.appendingPathComponent(name))
    self.properties[name] = nil
    performUpdates()
  }
}

extension DocumentPropertiesIndex: MetadataQueryDelegate {
  fileprivate func updateProperties(for fileMetadata: FileMetadataWrapper) {
    let name = fileMetadata.value.fileName
    if properties[name]?.value.fileMetadata.contentChangeDate ==
      fileMetadata.value.contentChangeDate {
      // Just update the fileMetadata structure without re-extracting document properties.
      properties[name]?.updateMetadata(fileMetadata.value)
      return
    }

    // Put an entry in the properties dictionary that contains the current
    // contentChangeDate. We'll replace it with something with the actual extracted
    // properties in the completion block below. This is needed to prevent multiple
    // loads for the same content.
    if properties[name] == nil {
      properties[name] = DocumentPropertiesListDiffable(fileMetadata.value)
    } else {
      // Update change time to prevent multiple loads
      properties[name]?.updateMetadata(fileMetadata.value)
    }
    DocumentProperties.loadProperties(
      from: fileMetadata,
      in: containerURL,
      parsingRules: parsingRules
    ) { (result) in
      switch result {
      case .success(let properties):
        self.properties[name] = DocumentPropertiesListDiffable(properties)
        DDLogInfo("Successfully loaded: " + properties.title)
        self.performUpdates()
      case .failure(let error):
        self.properties[name] = nil
        DDLogError("Error loading properties: \(error)")
      }
    }
  }

  public func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem]) {
    let specialNames: Set<String> = [StudyHistory.name, DocumentPropertiesIndexDocument.name]
    let models = items
      .map { FileMetadataWrapper(metadataItem: $0) }
      .filter { !specialNames.contains($0.value.fileName) }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded(in: containerURL)
      updateProperties(for: fileMetadata)
    }
    performUpdates()
  }
}
