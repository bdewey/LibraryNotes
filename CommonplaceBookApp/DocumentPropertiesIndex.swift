// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import Foundation
import IGListKit
import MiniMarkdown

public final class DocumentPropertiesIndex: NSObject {

  public init(parsingRules: ParsingRules, stylesheet: Stylesheet) {
    self.parsingRules = parsingRules
    self.stylesheet = stylesheet
  }

  public let parsingRules: ParsingRules
  fileprivate let stylesheet: Stylesheet
  public weak var adapter: ListAdapter?
  fileprivate var properties: [URL: DocumentPropertiesListDiffable] = [:]

  public private(set) lazy var documentDataSource: DocumentDataSource = {
    return DocumentDataSource(index: self)
  }()

  public private(set) lazy var hashtagDataSource: HashtagDataSource = {
    return HashtagDataSource(index: self)
  }()

  public func deleteDocument(_ properties: DocumentPropertiesListDiffable) {
    let url = properties.value.fileMetadata.fileURL
    try? FileManager.default.removeItem(at: url)
    self.properties[url] = nil
    adapter?.performUpdates(animated: true)
    hashtagDataSource.adapter?.performUpdates(animated: true)
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

public final class DocumentDataSource: NSObject, ListAdapterDataSource {
  public init(index: DocumentPropertiesIndex) {
    self.index = index
  }

  private weak var index: DocumentPropertiesIndex?

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    guard let index = index else { return [] }
    return index.properties.values
      .filter { !$0.value.placeholder }
      .sorted(
        by: { $0.value.fileMetadata.contentChangeDate > $1.value.fileMetadata.contentChangeDate }
      )
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return DocumentSectionController(index: index!, stylesheet: index!.stylesheet)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}

public final class HashtagDataSource: NSObject, ListAdapterDataSource {
  public init(index: DocumentPropertiesIndex) {
    self.index = index
  }

  private weak var index: DocumentPropertiesIndex?
  public weak var adapter: ListAdapter?

  public func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    guard let index = index else { return [] }
    let hashtags = index.properties.values.reduce(into: Set<String>()) { (hashtags, props) in
      hashtags.formUnion(props.value.hashtags)
    }
    return Array(hashtags).sorted().map { Hashtag($0) }
  }

  public func listAdapter(
    _ listAdapter: ListAdapter,
    sectionControllerFor object: Any
  ) -> ListSectionController {
    return HashtagSectionController(stylesheet: index!.stylesheet)
  }

  public func emptyView(for listAdapter: ListAdapter) -> UIView? {
    return nil
  }
}
