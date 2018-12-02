// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import TextBundleKit

public protocol FileMetadataProviderDelegate: class {

  /// Sent when there are new FileMetadata items in the provider.
  ///
  /// - parameter provider: The file metadata provider
  /// - parameter metadata: The updated copy of the FileMetadata array.
  func fileMetadataProvider(_ provider: FileMetadataProvider, didUpdate metadata: [FileMetadata])
}

/// A FileMetadataProvider knows how to obtain all of the FileMetadata structures corresponding
/// to a single container (e.g., iCloud container or documents folder)
public protocol FileMetadataProvider {

  var container: URL { get }

  /// The current array of metadata.
  var fileMetadata: [FileMetadata] { get }

  /// Delegate that can receive notifications when `fileMetadata` changes.
  var delegate: FileMetadataProviderDelegate? { get set }

  /// Gets the EditableDocument that corresponds to a particular piece of metadata.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument?
}

extension FileMetadataProvider {

  /// Default implementation of editableDocument -- will work for any FileMetadataProvider
  /// that is named by URLs that a UIDocument can open.
  public func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
    let fileURL = container.appendingPathComponent(metadata.fileName)
    switch metadata.contentType {
    case "public.plain-text", "public.json":
      return PlainTextDocument(fileURL: fileURL)
    case "org.textbundle.package", "org.brians-brain.swiftflash":
      return TextBundleDocument(fileURL: fileURL)
    default:
      return nil
    }
  }
}

/// A FileMetadataProvider for the iCloud ubiquitous container.
///
/// TODO: At some point, write one of these for local files based on NSFilePresenter
/// for monitoring.
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
