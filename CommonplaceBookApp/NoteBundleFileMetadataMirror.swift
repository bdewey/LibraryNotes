// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import UIKit

/// This class watches content in a FileMetadataProvider. As content changes, it updates
/// the properties inside the NoteBundleDocument. (Similar to performing continual incremental
/// recompile of source.) Then, based upon those properties, specifically the "title", it may
/// try to rename files in the Metadata provider.
public final class NoteBundleFileMetadataMirror {

  /// Sets up the mirror.
  ///
  /// - precondition: `document` is closed. It will get opened by the mirror.
  /// - precondition: `metadataProvider` must not have a delegate.
  ///                  This instance will be the delegate.
  public init(document: NoteBundleDocument, metadataProvider: FileMetadataProvider) {
    precondition(document.documentState == .closed)
    precondition(metadataProvider.delegate == nil)
    self.document = document
    self.metadataProvider = metadataProvider

    observerTokens.append(
      NotificationCenter.default.addObserver(
        forName: UIDocument.stateChangedNotification,
        object: document,
        queue: OperationQueue.main,
        using: { [weak self] _ in
          self?.documentStateChanged()
        }
      )
    )
    document.openOrCreate { success in
      DDLogDebug("Opened note bundle: \(success), state = \(document.documentState)")
    }
    metadataProvider.delegate = self
  }

  deinit {
    observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private let document: NoteBundleDocument
  private let metadataProvider: FileMetadataProvider
  private var observerTokens = [NSObjectProtocol]()

  /// Responds to changes in document state.
  private func documentStateChanged() {
    guard !document.documentState.contains(.closed) else { return }
    if document.documentState.contains(.inConflict) {
      DDLogError("Conflict! Dont handle that yet :-(")
    } else if document.documentState.contains(.editingDisabled) {
      DDLogError("Editing disabled. Why?")
    } else {
      processMetadata(metadataProvider.fileMetadata)
    }
  }
}

extension NoteBundleFileMetadataMirror: FileMetadataProviderDelegate {
  public func fileMetadataProvider(
    _ provider: FileMetadataProvider,
    didUpdate metadata: [FileMetadata]
  ) {
    processMetadata(metadata)
  }

  private func processMetadata(_ metadata: [FileMetadata]) {
    guard document.documentState.intersection([.closed, .editingDisabled]).isEmpty else { return }
    let models = metadata
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded(in: metadataProvider.container)
      document.updatePage(for: fileMetadata, in: metadataProvider, completion: nil)
    }
  }
}
