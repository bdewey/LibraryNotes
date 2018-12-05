// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import CwlSignal
import Foundation
import IGListKit
import MiniMarkdown
import TextBundleKit

extension Tag {
  public static let fromCache = Tag(rawValue: "fromCache")
  public static let placeholder = Tag(rawValue: "placeholder")
  public static let truth = Tag(rawValue: "truth")
}

public protocol NotebookPageChangeListener: AnyObject {

  /// Properties in the index changed.
  func notebookPagesDidChange(_ index: Notebook)
}

/// A "notebook" is a directory that contains individual "pages" (either plain text files
/// or textbundle bundles). Each page may contain "cards", which are individual facts to review
/// using a spaced repetition algorithm.
public final class Notebook {

  public static let cachedPropertiesName = "properties.json"

  /// Designated initializer.
  ///
  /// - parameter parsingrules: The rules used to parse the text content of documents.
  /// - parameter metadataProvider: Where we store all of the pages of the notebook (+ metadata)
  public init(
    parsingRules: ParsingRules,
    metadataProvider: FileMetadataProvider
  ) {
    self.parsingRules = parsingRules
    self.metadataProvider = metadataProvider

    self.propertiesDocument = metadataProvider.editableDocument(
      for: FileMetadata(fileName: Notebook.cachedPropertiesName)
    )

    // CODE SMELL. Need to process any existing file metadata.
    // TODO: Figure out and then WRITE TESTS FOR what's supposed to happen if the cached properties
    //       don't match what's in the metadata provider (which is truth)
    self.metadataProvider.delegate = self
    self.fileMetadataProvider(metadataProvider, didUpdate: metadataProvider.fileMetadata)

    monitorPropertiesDocument(propertiesDocument)
  }

  deinit {
    propertiesDocument?.close()
  }

  private var propertiesEndpoint: Cancellable?

  public static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  public var metadataProvider: FileMetadataProvider

  /// Provides access to the container URL
  public var containerURL: URL { return metadataProvider.container }

  /// Where we cache our properties.
  private let propertiesDocument: EditableDocument?

  /// Set up the code to monitor for changes to cached properties on disk, plus propagate
  /// cached changes to disk.
  private func monitorPropertiesDocument(_ propertiesDocument: EditableDocument?) {
    guard let propertiesDocument = propertiesDocument else { return }
    propertiesDocument.open { (success) in
      // TODO: Handle the failure case here.
      precondition(success)
      self.propertiesEndpoint = propertiesDocument.textSignal.subscribeValues({ (taggedString) in
        guard let properties = try? Notebook.decoder.decode([DocumentProperties].self, from: taggedString.value.data(using: .utf8)!) else { return }
        self.pages = properties.reduce(
          into: [String: Tagged<DocumentProperties>]()
        ) { (dictionary, properties) in
          dictionary[properties.fileMetadata.fileName] = Tagged(
            tag: .fromCache,
            value: properties
          )
        }
      })
    }
  }

  /// The pages of the notebook.
  public internal(set) var pages: [String: Tagged<DocumentProperties>] = [:] {
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

    // TODO: This should be done through the metadata provider
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

extension Notebook: FileMetadataProviderDelegate {
  public func fileMetadataProvider(
    _ provider: FileMetadataProvider,
    didUpdate metadata: [FileMetadata]
  ) {
    let specialNames: Set<String> = [StudyHistory.name, Notebook.cachedPropertiesName]
    let models = metadata
      .filter { !specialNames.contains($0.fileName) }
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded(in: containerURL)
      updateProperties(for: fileMetadata)
    }
  }

  fileprivate func updateProperties(for fileMetadata: FileMetadata) {
    let name = fileMetadata.fileName
    if let taggedProperties = pages[name],
           taggedProperties.value.fileMetadata.contentChangeDate ==
             fileMetadata.contentChangeDate {
      // Just update the fileMetadata structure without re-extracting document properties.
      pages[name] = Tagged(
        tag: .truth,
        value: taggedProperties.value.updatingFileMetadata(fileMetadata)
      )
      return
    }

    // Put an entry in the properties dictionary that contains the current
    // contentChangeDate. We'll replace it with something with the actual extracted
    // properties in the completion block below. This is needed to prevent multiple
    // loads for the same content.
    if let taggedProperties = pages[name] {
      // Update change time to prevent multiple loads
      // TODO: this is copypasta from above. Code smell; can probably simplify
      pages[name] = Tagged(
        tag: .placeholder, // TODO: Should be called "pending"?
        value: taggedProperties.value.updatingFileMetadata(fileMetadata)
      )
    } else {
      pages[name] = Tagged(
        tag: .placeholder,
        value: DocumentProperties(fileMetadata: fileMetadata, nodes: [])
      )
    }

    DocumentProperties.loadProperties(
      from: fileMetadata,
      in: metadataProvider,
      parsingRules: parsingRules
    ) { (result) in
      switch result {
      case .success(let properties):
        self.pages[name] = Tagged(tag: .truth, value: properties)
        DDLogInfo("Successfully loaded: " + properties.title)
        self.notifyListeners()
      case .failure(let error):
        self.pages[name] = nil
        DDLogError("Error loading properties: \(error)")
      }
    }
  }
}
