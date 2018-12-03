// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import Foundation
import IGListKit
import MiniMarkdown

public protocol NotebookPageChangeListener: AnyObject {

  /// Properties in the index changed.
  func notebookPagesDidChange(_ index: Notebook)
}

/// A "notebook" is a directory that contains individual "pages" (either plain text files
/// or textbundle bundles). Each page may contain "cards", which are individual facts to review
/// using a spaced repetition algorithm.
public final class Notebook {

  /// Designated initializer.
  ///
  /// - parameter containerURL: The URL of the directory that contains all of the indexed
  ///                           documents.
  /// - parameter parsingrules: The rules used to parse the text content of documents.
  public init(
    parsingRules: ParsingRules,
    propertiesDocument: DocumentPropertiesIndexProtocol,
    metadataProvider: FileMetadataProvider
  ) {
    self.parsingRules = parsingRules
    self.metadataProvider = metadataProvider
    self.propertiesDocument = propertiesDocument
    self.propertiesDocument.delegate = self
    // CODE SMELL. Need to process any existing file metadata.
    // TODO: Figure out and then WRITE TESTS FOR what's supposed to happen if the cached properties
    //       don't match what's in the metadata provider (which is truth)
    self.metadataProvider.delegate = self
    self.fileMetadataProvider(metadataProvider, didUpdate: metadataProvider.fileMetadata)

    // TODO: Handle the "nil" case
    let propertiesDocument = metadataProvider.editableDocument(for: FileMetadata(fileName: "properties.json"))!
    propertiesDocument.open { (success) in
      // TODO: Handle the failure case here.
      precondition(success)
      propertiesDocument.close()
    }
  }

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  public var metadataProvider: FileMetadataProvider

  /// Provides access to the container URL
  public var containerURL: URL { return metadataProvider.container }

  private let propertiesDocument: DocumentPropertiesIndexProtocol

  /// The pages of the notebook.
  public internal(set) var pages: [String: DocumentProperties] = [:] {
    didSet {
      notifyListeners()
    }
  }

  private struct WeakListener {
    weak var listener: NotebookPageChangeListener?
    init(_ listener: NotebookPageChangeListener) { self.listener = listener }
  }
  private var listeners: [WeakListener] = []

  /// Registers an NotebookPageChangeListener.
  ///
  /// - parameter listener: The listener to register. It will get notifications of changes.
  public func addListener(_ listener: NotebookPageChangeListener) {
    listeners.append(WeakListener(listener))
  }

  /// Removes the NotebookPageChangeListener. It will no longer get notifications of changes.
  ///
  /// - parameter listener: The listener to unregister.
  public func removeListener(_ listener: NotebookPageChangeListener) {
    guard let index = listeners.firstIndex(where: { $0.listener === listener }) else { return }
    listeners.remove(at: index)
  }

  /// Tell all registered list adapters to perform updates.
  private func notifyListeners() {
    for adapter in listeners {
      adapter.listener?.notebookPagesDidChange(self)
    }
  }

  /// Deletes a document and its properties.
  public func deleteDocument(_ properties: DocumentPropertiesListDiffable) {
    let name = properties.value.fileMetadata.fileName
    try? FileManager.default.removeItem(at: containerURL.appendingPathComponent(name))
    self.pages[name] = nil
  }
}

/// Any IGListKit ListAdapter can be a NotebookPageChangeListener.
extension ListAdapter: NotebookPageChangeListener {
  public func notebookPagesDidChange(_ index: Notebook) {
    performUpdates(animated: true)
  }
}

extension Notebook: DocumentPropertiesIndexDocumentDelegate {

  public func indexDocument(
    _ document: DocumentPropertiesIndexDocument,
    didLoadProperties properties: [DocumentProperties]
  ) {
    // TODO: Will this race with getting properties from the metadata provider?
    self.pages = properties.reduce(
      into: [String: DocumentProperties]()
    ) { (dictionary, properties) in
      dictionary[properties.fileMetadata.fileName] = properties
    }
  }

  public func indexDocumentPropertiesToSave(
    _ document: DocumentPropertiesIndexDocument
  ) -> [DocumentProperties] {
    return Array(pages.values)
  }
}

extension Notebook: FileMetadataProviderDelegate {
  public func fileMetadataProvider(
    _ provider: FileMetadataProvider,
    didUpdate metadata: [FileMetadata]
  ) {
    let specialNames: Set<String> = [StudyHistory.name, DocumentPropertiesIndexDocument.name]
    let models = metadata
      .filter { !specialNames.contains($0.fileName) }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded(in: containerURL)
      updateProperties(for: fileMetadata)
    }
  }

  fileprivate func updateProperties(for fileMetadata: FileMetadata) {
    let name = fileMetadata.fileName
    if pages[name]?.fileMetadata.contentChangeDate ==
      fileMetadata.contentChangeDate {
      // Just update the fileMetadata structure without re-extracting document properties.
      pages[name]?.fileMetadata = fileMetadata
      return
    }

    // Put an entry in the properties dictionary that contains the current
    // contentChangeDate. We'll replace it with something with the actual extracted
    // properties in the completion block below. This is needed to prevent multiple
    // loads for the same content.
    if pages[name] == nil {
      pages[name] = DocumentProperties(fileMetadata: fileMetadata, nodes: [])
    } else {
      // Update change time to prevent multiple loads
      pages[name]?.fileMetadata = fileMetadata
    }
    DocumentProperties.loadProperties(
      from: fileMetadata,
      in: metadataProvider,
      parsingRules: parsingRules
    ) { (result) in
      switch result {
      case .success(let properties):
        self.pages[name] = properties
        DDLogInfo("Successfully loaded: " + properties.title)
        self.notifyListeners()
      case .failure(let error):
        self.pages[name] = nil
        DDLogError("Error loading properties: \(error)")
      }
    }
  }
}
