// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Logging
import Foundation

/// Exposes the files in a directory as a FileMetadataProvider.
public final class DirectoryMetadataProvider: NSObject, FileMetadataProvider {
  /// Designated initializer.
  ///
  /// - parameter container: The URL to the directory
  /// - parameter deleteExistingContents: If true, then all files in `container` at the time
  ///             of metadata provider creation will get deleted, guaranteeing a clean container.
  ///             Intended for testing.
  public init(container: URL, deleteExistingContents: Bool = false) throws {
    self.container = container
    if deleteExistingContents {
      try? FileManager.default.removeItem(at: container)
      try FileManager.default.createDirectory(
        at: container,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
    super.init()
    NSFileCoordinator.addFilePresenter(self)
    try extractMetadata()
  }

  public let container: URL

  public private(set) var fileMetadata: [FileMetadata] = [] {
    didSet {
      delegate?.fileMetadataProvider(self, didUpdate: fileMetadata)
    }
  }

  public func queryForCurrentFileMetadata(completion: @escaping ([FileMetadata]) -> Void) {
    completion(fileMetadata)
  }

  public weak var delegate: FileMetadataProviderDelegate?

  public func delete(_ metadata: FileMetadata) throws {
    try FileManager.default.removeItem(at: container.appendingPathComponent(metadata.fileName))
  }

  public func itemExists(with pathComponent: String) throws -> Bool {
    return FileManager.default.fileExists(
      atPath: container.appendingPathComponent(pathComponent).path
    )
  }

  public func renameMetadata(_ metadata: FileMetadata, to name: String) throws {
    try FileManager.default.moveItem(
      at: container.appendingPathComponent(metadata.fileName),
      to: container.appendingPathComponent(name)
    )
    try extractMetadata()
  }

  fileprivate func extractMetadata() throws {
    let items = try FileManager.default.contentsOfDirectory(
      at: container,
      includingPropertiesForKeys: nil,
      options: []
    )
    Logger.shared.info("Found \(items.count) items in the container")
    fileMetadata = try items.map { (url) -> FileMetadata in
      try FileMetadata(fileURL: url)
    }
  }

  fileprivate func extractMetadataAndLogOnError() {
    do {
      try extractMetadata()
    } catch {
      Logger.shared.error("Unexpected error extracting metadata from \(container): \(error)")
    }
  }
}

extension DirectoryMetadataProvider: NSFilePresenter {
  public var presentedItemURL: URL? {
    return container
  }

  public var presentedItemOperationQueue: OperationQueue {
    return OperationQueue.main
  }

  public func presentedSubitemDidChange(at url: URL) {
    extractMetadataAndLogOnError()
  }

  public func presentedSubitemDidAppear(at url: URL) {
    extractMetadataAndLogOnError()
  }

  public func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
    extractMetadataAndLogOnError()
  }
}
