// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CwlSignal
import Foundation
import TextBundleKit

extension Notebook.Key {
  public static let pageProperties = Notebook.Key(rawValue: "properties.json")
}

extension Tag {
  public static let renamedCopy = Tag(rawValue: "renamedCopy")
}

/// Notebook functionality responsible for the "pages" data -- mapping of name to PageProperties.
extension Notebook {
  public typealias TaggedPageDictionary = [String: Tagged<PageProperties>]

  /// The pages of the notebook.
  public internal(set) var pageProperties: TaggedPageDictionary {
    get {
      if let pages = internalNotebookData[.pageProperties] as? TaggedPageDictionary {
        return pages
      } else {
        let pages = TaggedPageDictionary()
        internalNotebookData[.pageProperties] = pages
        return pages
      }
    }
    set {
      internalNotebookData[.pageProperties] = newValue
    }
  }

  public func pagesDictionary(
    from seralizedString: String,
    tag: Tag
  ) -> TaggedPageDictionary {
    guard let data = seralizedString.data(using: .utf8) else { return [:] }
    do {
      let properties = try decoder.decode(
        [PageProperties].self,
        from: data
      )
      return properties.reduce(
        into: [String: Tagged<PageProperties>]()
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

  @discardableResult
  public func loadCachedProperties() -> Notebook {
    if let propertiesDocument = metadataProvider.editableDocument(
      for: FileMetadata(fileName: Key.pageProperties.rawValue)
      ) {
      openMetadocuments[.pageProperties] = propertiesDocument
      monitorPropertiesDocument(propertiesDocument)
    } else {
      DDLogError("Unexpected error: Unable to load cached properties. Continuing without cache.")
    }
    self.renameBlocks[.pageProperties] = { [weak self](oldName, newName) in
      guard let self = self else { return }
      try self.metadataProvider.renameMetadata(FileMetadata(fileName: oldName), to: newName)
      if let existingProperties = self.pageProperties[oldName]?.value {
        self.pageProperties[newName] = Tagged<PageProperties>(
          tag: Tag.renamedCopy,
          value: existingProperties.renaming(to: newName)
        )
        self.pageProperties[oldName] = nil
      }
      self.notifyListeners(changed: .pageProperties)
      self.saveProperties()
    }
    return self
  }

  @discardableResult
  public func monitorMetadataProvider() -> Notebook {
    DispatchQueue.main.async(
      when: conditionForKey(.pageProperties)
    ) {
      self.metadataProvider.delegate = self
      self.processMetadata(self.metadataProvider.fileMetadata)
    }
    return self
  }

  /// Set up the code to monitor for changes to cached properties on disk, plus propagate
  /// cached changes to disk.
  private func monitorPropertiesDocument(_ propertiesDocument: EditableDocument) {
    propertiesDocument.open { (success) in
      // TODO: Handle the failure case here.
      precondition(success)
      self.endpoints += propertiesDocument.textSignal.subscribeValues({ (taggedString) in
        // If we've already loaded information into memory, don't clobber it.
        if self.pageProperties.isEmpty {
          let pages = self.pagesDictionary(from: taggedString.value, tag: .fromCache)
          DDLogInfo("Loaded information about \(pages.count) page(s) from cache")
          self.pageProperties = pages
          self.notifyListeners(changed: .pageProperties)
        }
        self.conditionForKey(.pageProperties).condition = true
      })
    }
  }

  private func processMetadata(_ metadata: [FileMetadata]) {
    let models = metadata
      .filter { !Key.allKnownKeys.contains($0.fileName) }
    deletePages(except: models)
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
      self.notifyListeners(changed: .pageProperties)
    }
  }

  private func updateProperties(
    for fileMetadata: FileMetadata,
    completion: @escaping (Bool) -> Void
  ) {
    let name = fileMetadata.fileName

    let newProperties = pageProperties[name].updatingFileMetadata(fileMetadata)
    pageProperties[name] = newProperties
    if newProperties.tag == .truth {
      DDLogInfo("NOTEBOOK: Keeping cached properties for \(name).")
      completion(false)
      return
    }

    DDLogInfo("NOTEBOOK: Loading new properties for \(name)")
    PageProperties.loadProperties(
      from: fileMetadata,
      in: metadataProvider,
      parsingRules: parsingRules
    ) { (result) in
      switch result {
      case .success(let properties):
        self.pageProperties[name] = Tagged(tag: .truth, value: properties)
        DDLogInfo("Successfully loaded: " + properties.title)
      case .failure(let error):
        self.pageProperties[name] = nil
        DDLogError("Error loading properties: \(error)")
      }
      completion(true)
    }
  }

  private func saveProperties() {
    guard let propertiesDocument = openMetadocuments[.pageProperties] else { return }
    // TODO: Move serialization off main thread?
    do {
      let properties = pageProperties.values.map { $0.value }
      let data = try Notebook.encoder.encode(properties)
      propertiesDocument.applyTaggedModification(tag: .memory) { (_) -> String in
        return String(data: data, encoding: .utf8) ?? ""
      }
    } catch {
      DDLogError("\(error)")
    }
  }

  /// The list of pages where the name does not match the desired base name.
  /// The keys are existing file names. The values are desired *base* names
  /// (no extensions, no uniqifiers).
  public var desiredBaseNameForPage: [String: String] {
    var results = [String: String]()
    for (page, taggedProperties) in pageProperties
      where !taggedProperties.value.hasDesiredBaseFileName {
      results[page] = taggedProperties.value.desiredBaseFileName
    }
    return results
  }

  public func performRenames(_ desiredBaseNameForPage: [String: String]) throws {
    guard !desiredBaseNameForPage.isEmpty else { return }
    try performBatchUpdates {
      for (existingPage, baseName) in desiredBaseNameForPage {
        let pathExtension = (existingPage as NSString).pathExtension
        let newName = FileNameGenerator(baseName: baseName, pathExtension: pathExtension)
          .firstName(notIn: metadataProvider)
        DDLogInfo("Renaming \(existingPage) to \(newName)")
        try self.renamePage(from: existingPage, to: newName)
      }
    }
  }

  /// Removes items "pages" except those referenced by `metadata`
  /// - note: This does *not* save cached properties. That is the responsibility of the caller.
  /// TODO: I should redesign the page manipulation APIs to be more foolproof.
  ///       A method that takes a block, executes it, then notifies listeners & saves properties
  ///       afterwards. That will batch saves as well as listener notifications.
  ///       This implementation will send one notification per key.
  private func deletePages(except metadata: [FileMetadata]) {
    let existingKeys = Set<String>(pageProperties.keys)
    let metadataProviderKeys = Set<String>(metadata.map({ $0.fileName }))
    let keysToDelete = existingKeys.subtracting(metadataProviderKeys)
    for key in keysToDelete {
      pageProperties[key] = nil
    }
  }

  /// Deletes a document and its properties.
  public func deleteFileMetadata(_ fileMetadata: FileMetadata) {
    try? metadataProvider.delete(fileMetadata)
    self.pageProperties[fileMetadata.fileName] = nil
    saveProperties()
  }
}

extension Optional where Wrapped == Tagged<PageProperties> {

  /// Given an optional Tagged<DocumentProperties>, computes a new Tagged<DocumentProperties>
  /// for given metadata.
  ///
  /// If the receiver has no value, then the result is a Tag.placeholder
  /// with empty DocumentProperties.
  ///
  /// If the receiver has a value, then the result updates the DocumentProperties with the new
  /// FileMetadata (to handle things that change like uploading status). It will be marked
  /// with Tag.truth (meaning no need to re-parse) if the timestamps are close.
  fileprivate func updatingFileMetadata(
    _ fileMetadata: FileMetadata
    ) -> Tagged<PageProperties> {
    switch self {
    case .none:
      return Tagged(
        tag: .placeholder,
        value: PageProperties(fileMetadata: fileMetadata, nodes: [])
      )
    case .some(let wrapped):
      return Tagged(
        tag: wrapped.value.fileMetadata.closeInTime(to: fileMetadata) ? .truth : .placeholder,
        value: wrapped.value.updatingFileMetadata(fileMetadata)
      )
    }
  }
}

extension FileMetadata {

  /// Determine if two FileMetadata records are "close enough" that we don't have to
  /// re-load and re-parse the file contents.
  fileprivate func closeInTime(to other: FileMetadata) -> Bool {
    return abs(contentChangeDate.timeIntervalSince(other.contentChangeDate)) < 1
  }
}

extension Notebook: FileMetadataProviderDelegate {
  public func fileMetadataProvider(
    _ provider: FileMetadataProvider,
    didUpdate metadata: [FileMetadata]
    ) {
    processMetadata(metadata)
  }
}
