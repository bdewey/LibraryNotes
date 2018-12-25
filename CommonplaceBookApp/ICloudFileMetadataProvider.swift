// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

/// A FileMetadataProvider for the iCloud ubiquitous container.
public final class ICloudFileMetadataProvider: FileMetadataProvider {

  public init(container: URL) {
    assert(Thread.isMainThread)
    self.container = container
    query = NSMetadataQuery()
    query.predicate = NSComparisonPredicate.page
    query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    query.searchItems = [container]
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didFinishGatheringNotification(_:)),
      name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
      object: query
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didUpdateNotification(_:)),
      name: NSNotification.Name.NSMetadataQueryDidUpdate,
      object: query
    )
    query.enableUpdates()
    query.start()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  /// Up to date copy of file metadata
  public private(set) var fileMetadata = [FileMetadata]() {
    didSet {
      delegate?.fileMetadataProvider(self, didUpdate: fileMetadata)
    }
  }
  public weak var delegate: FileMetadataProviderDelegate?

  /// the specific ubiquitous container we monitor.
  public let container: URL

  /// Our active query for documents
  private let query: NSMetadataQuery

  public func delete(_ metadata: FileMetadata) throws {
    try FileManager.default.removeItem(at: container.appendingPathComponent(metadata.fileName))
  }

  public func itemExists(with pathComponent: String) throws -> Bool {
    let url = container.appendingPathComponent(pathComponent)
    return try url.checkPromisedItemIsReachable()
  }

  public func renameMetadata(_ metadata: FileMetadata, to name: String) throws {
    let url = container.appendingPathComponent(metadata.fileName)
    let destinationURL = container.appendingPathComponent(name)
    try FileManager.default.moveItem(at: url, to: destinationURL)
  }

  @objc private func didFinishGatheringNotification(_ notification: NSNotification) {
    self.fileMetadata = query.results.compactMap({ (maybeMetadataItem) -> FileMetadata? in
      guard let metadataItem = maybeMetadataItem as? NSMetadataItem else { return nil }
      return FileMetadata(metadataItem: metadataItem)
    })
  }

  @objc private func didUpdateNotification(_ notification: NSNotification) {
    DDLogInfo("Received notification: " + String(describing: notification.userInfo))
    self.fileMetadata = query.results.compactMap({ (maybeMetadataItem) -> FileMetadata? in
      guard let metadataItem = maybeMetadataItem as? NSMetadataItem else { return nil }
      return FileMetadata(metadataItem: metadataItem)
    })
  }
}

extension NSComparisonPredicate {

  /// Convenience initializer that finds items that conform to a UTI.
  fileprivate convenience init(conformingToUTI uti: String) {
    self.init(
      leftExpression: NSExpression(forKeyPath: "kMDItemContentTypeTree"),
      rightExpression: NSExpression(forConstantValue: uti),
      modifier: .any,
      type: .like,
      options: []
    )
  }

  /// Predicate that finds pages (plain text, textbundles)
  fileprivate static let page = NSCompoundPredicate(orPredicateWithSubpredicates: [
    NSComparisonPredicate(conformingToUTI: "public.plain-text"),
    NSComparisonPredicate(conformingToUTI: "org.textbundle.package"),
    ])
}
