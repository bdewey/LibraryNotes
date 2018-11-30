// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import UIKit

/// A "notebook" is a directory that contains individual "pages" (either plain text files
/// or textbundle bundles). Each page may contain "cards", which are individual facts to review
/// using a spaced repetition algorithm.
public final class Notebook {
  public init(container: URL) {
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
  
  private let container: URL
  private let query: NSMetadataQuery
  private var items: [NSMetadataItem] = []

  @objc private func didFinishGatheringNotification(_ notification: NSNotification) {
    self.items = query.results as! [NSMetadataItem]
  }
  
  @objc private func didUpdateNotification(_ notification: NSNotification) {
    DDLogInfo("Received notification: " + String(describing: notification.userInfo))
    self.items = query.results as! [NSMetadataItem]
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

