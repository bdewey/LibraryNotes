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
    print("Received notification: \(notification.userInfo)")
    let items = query.results as! [NSMetadataItem] // swiftlint:disable:this force_cast
    delegate?.metadataQuery(self, didFindItems: items)
  }
}
