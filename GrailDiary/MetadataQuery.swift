// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public protocol MetadataQueryDelegate: class {
  func metadataQuery(_ metadataQuery: MetadataQuery, didFindItems items: [NSMetadataItem])
}

public final class MetadataQuery {
  private let query: NSMetadataQuery
  private weak var delegate: MetadataQueryDelegate?

  public init(predicate: NSPredicate?, delegate: MetadataQueryDelegate) {
    self.delegate = delegate
    self.query = NSMetadataQuery()
    query.predicate = predicate
    query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
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

  @objc func didFinishGatheringNotification(_ notification: NSNotification) {
    let items = query.results as! [NSMetadataItem] // swiftlint:disable:this force_cast
    delegate?.metadataQuery(self, didFindItems: items)
  }

  @objc func didUpdateNotification(_ notification: NSNotification) {
    let items = query.results as! [NSMetadataItem] // swiftlint:disable:this force_cast
    delegate?.metadataQuery(self, didFindItems: items)
  }
}
