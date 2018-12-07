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

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.userInfo[.markdownParsingRules] = parsingRules
    self.decoder = decoder

    self.propertiesDocument = metadataProvider.editableDocument(
      for: FileMetadata(fileName: Notebook.cachedPropertiesName)
    )
    if self.propertiesDocument == nil {
      DDLogError("Unexpected error: Unable to load cached properties. Continuing without cache.")
    }
  }

  @discardableResult
  public func loadCachedProperties() -> Notebook {
    monitorPropertiesDocument()
    return self
  }

  @discardableResult
  public func monitorMetadataProvider() -> Notebook {
    self.metadataProvider.delegate = self
    processMetadata(metadataProvider.fileMetadata)
    return self
  }

  deinit {
    propertiesDocument?.close()
  }

  private var propertiesEndpoint: Cancellable?

  /// Decoder for this notebook. It depend on the parsing rules, which is why it is an instance
  /// property and not a class property.
  public let decoder: JSONDecoder

  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  public let metadataProvider: FileMetadataProvider

  /// Provides access to the container URL
  public var containerURL: URL { return metadataProvider.container }

  /// Where we cache our properties.
  private let propertiesDocument: EditableDocument?

  /// Set up the code to monitor for changes to cached properties on disk, plus propagate
  /// cached changes to disk.
  private func monitorPropertiesDocument() {
    guard let propertiesDocument = self.propertiesDocument else { return }
    propertiesDocument.open { (success) in
      // TODO: Handle the failure case here.
      precondition(success)
      self.propertiesEndpoint = propertiesDocument.textSignal.subscribeValues({ (taggedString) in
        if taggedString.tag == .memory { return }
        let pages = self.pagesDictionary(from: taggedString.value, tag: .fromCache)
        DDLogInfo("Loaded information about \(pages.count) page(s) from cache")
        self.pages = pages
      })
    }
  }

  public func pagesDictionary(
    from seralizedString: String,
    tag: Tag
  ) -> [String: Tagged<DocumentProperties>] {
    guard let data = seralizedString.data(using: .utf8) else { return [:] }
    do {
      let properties = try decoder.decode(
        [DocumentProperties].self,
        from: data
      )
      return properties.reduce(
        into: [String: Tagged<DocumentProperties>]()
      ) { (dictionary, properties) in
        dictionary[properties.fileMetadata.fileName] = Tagged(
          tag: tag,
          value: properties
        )
      }
    } catch {
      DDLogError("Error parsing cached properties: \(error)")
    }
    return [:]
  }

  private func saveProperties() {
    guard let propertiesDocument = propertiesDocument else { return }
    // TODO: Move serialization off main thread?
    do {
      let properties = pages.values.map { $0.value }
      let data = try Notebook.encoder.encode(properties)
      propertiesDocument.applyTaggedModification(tag: .memory) { (_) -> String in
        return String(data: data, encoding: .utf8) ?? ""
      }
    } catch {
      DDLogError("\(error)")
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

  private func processMetadata(_ metadata: [FileMetadata]) {
    let specialNames: Set<String> = [StudyHistory.name, Notebook.cachedPropertiesName]
    let models = metadata
      .filter { !specialNames.contains($0.fileName) }
    let allUpdated = DispatchGroup()
    var loadedProperties = 0
    for fileMetadata in models {
      allUpdated.enter()
      fileMetadata.downloadIfNeeded(in: containerURL)
      updateProperties(for: fileMetadata) { (didLoadNewProperties) in
        if didLoadNewProperties { loadedProperties += 1 }
        allUpdated.leave()
      }
    }
    allUpdated.notify(queue: DispatchQueue.main) {
      if loadedProperties > 0 { self.saveProperties() }
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
    processMetadata(metadata)
  }

  fileprivate func updateProperties(
    for fileMetadata: FileMetadata,
    completion: @escaping (Bool) -> Void
  ) {
    let name = fileMetadata.fileName

    // TODO: Because of serialization, I won't re-parse changes that happen within a second.
    // There's probably a better way.
    if let taggedProperties = pages[name],
      abs(taggedProperties.value.fileMetadata.contentChangeDate.timeIntervalSince(fileMetadata.contentChangeDate)) < 1 {
      // Just update the fileMetadata structure without re-extracting document properties.
      DDLogInfo(
        "File \(name): Not updating properties because timestamps close. " +
        "Cache seconds: \(taggedProperties.value.fileMetadata.contentChangeDate.timeIntervalSince1970)" +
        "  Metadata seconds: \(fileMetadata.contentChangeDate.timeIntervalSince1970)"
      )
      pages[name] = Tagged(
        tag: .truth,
        value: taggedProperties.value.updatingFileMetadata(fileMetadata)
      )
      completion(false)
      return
    }

    // Put an entry in the properties dictionary that contains the current
    // contentChangeDate. We'll replace it with something with the actual extracted
    // properties in the completion block below. This is needed to prevent multiple
    // loads for the same content.
    if let taggedProperties = pages[name] {
      // Update change time to prevent multiple loads
      // TODO: this is copypasta from above. Code smell; can probably simplify
      DDLogInfo(
        "File \(name): **Updating properties** because timestamps differ by > 1s. " +
          "Cache seconds: \(taggedProperties.value.fileMetadata.contentChangeDate.timeIntervalSince1970)" +
        "  Metadata seconds: \(fileMetadata.contentChangeDate.timeIntervalSince1970)"
      )
      pages[name] = Tagged(
        tag: .placeholder, // TODO: Should be called "pending"?
        value: taggedProperties.value.updatingFileMetadata(fileMetadata)
      )
    } else {
      DDLogInfo("File \(name): Creating placeholder because no cache record")
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
      case .failure(let error):
        self.pages[name] = nil
        DDLogError("Error loading properties: \(error)")
      }
      completion(true)
    }
  }
}
