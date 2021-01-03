//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import Logging

/// A FileMetadataProvider for the iCloud ubiquitous container.
public final class ICloudFileMetadataProvider: FileMetadataProvider {
  public init(container: URL) {
    assert(Thread.isMainThread)
    self.container = container
    self.query = ICloudMetadataQuery(
      predicate: NSComparisonPredicate.page,
      enableUpdates: true,
      callbackQueue: .main,
      callback: { [weak self] _, items in
        self?.updateFileMetadata(with: items)
      }
    )
    query?.start()
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

  public func queryForCurrentFileMetadata(completion: @escaping ([FileMetadata]) -> Void) {
    assert(Thread.isMainThread)
    let adHocQuery = ICloudMetadataQuery(
      predicate: NSComparisonPredicate.page,
      enableUpdates: false,
      callbackQueue: .main
    ) { [weak self] query, items in
      let fileMetadata = items.map { FileMetadata(metadataItem: $0) }
      completion(fileMetadata)
      self?.activeQueries.removeAll(where: { $0 === query })
    }
    activeQueries.append(adHocQuery)
    adHocQuery.start()
  }

  public weak var delegate: FileMetadataProviderDelegate?

  /// the specific ubiquitous container we monitor.
  public let container: URL

  /// Our active query for documents
  private var query: ICloudMetadataQuery?

  private var activeQueries: [ICloudMetadataQuery] = []

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

  private func updateFileMetadata(with metadataItems: [NSMetadataItem]) {
    fileMetadata = metadataItems.map { (metadataItem) -> FileMetadata in
      FileMetadata(metadataItem: metadataItem)
    }
  }
}

/// Provides a block-based-callback API for querying for data in ubiquitous storage.
/// It can either provide just the initial gathered results, or initial results plus live updates.
private final class ICloudMetadataQuery {
  private let query: NSMetadataQuery
  private let enableUpdates: Bool
  private let callback: (ICloudMetadataQuery, [NSMetadataItem]) -> Void
  private let callbackQueue: DispatchQueue

  init(
    predicate: NSPredicate?,
    enableUpdates: Bool,
    callbackQueue: DispatchQueue,
    callback: @escaping (ICloudMetadataQuery, [NSMetadataItem]) -> Void
  ) {
    self.enableUpdates = enableUpdates
    self.callbackQueue = callbackQueue
    self.callback = callback

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
    query.start()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func start() {
    query.start()
  }

  @objc func didFinishGatheringNotification(_ notification: NSNotification) {
    let items = query.results as! [NSMetadataItem] // swiftlint:disable:this force_cast
    callbackQueue.async {
      self.callback(self, items)
    }
    if enableUpdates {
      query.enableUpdates()
    }
  }

  @objc func didUpdateNotification(_ notification: NSNotification) {
    let items = query.results as! [NSMetadataItem] // swiftlint:disable:this force_cast
    callbackQueue.async {
      self.callback(self, items)
    }
  }
}

private extension NSComparisonPredicate {
  /// Convenience initializer that finds items that conform to a UTI.
  convenience init(conformingToUTI uti: String) {
    self.init(
      leftExpression: NSExpression(forKeyPath: "kMDItemContentTypeTree"),
      rightExpression: NSExpression(forConstantValue: uti),
      modifier: .any,
      type: .like,
      options: []
    )
  }

  /// Predicate that finds pages (plain text, textbundles)
  static let page = NSCompoundPredicate(orPredicateWithSubpredicates: [
    NSComparisonPredicate(conformingToUTI: "public.plain-text"),
    NSComparisonPredicate(conformingToUTI: "org.textbundle.package"),
  ])
}
