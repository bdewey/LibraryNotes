// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

/// A document cache vends *open* UIDocument instances given a file name.
public protocol DocumentCache {
  func document(for name: String, completion: @escaping (UIDocument?) -> Void)
}

public protocol ReadOnlyDocumentCacheDelegate: class {
  /// Retreives the document for the given name.
  /// - returns: An initialized but unopened UIDocument.
  func documentCache(_ cache: ReadOnlyDocumentCache, documentFor name: String) -> UIDocument?
}

/// Maintains a cache of open UIDocuments. The intent is that we only read through these documents,
/// though nothing stops writing. Upon deallocating this instance, all documents will be closed.
public final class ReadOnlyDocumentCache: DocumentCache {
  /// Designated initializer.
  ///
  /// - parameter delegate: Cache delegate. Will be weakly held.
  public init(delegate: ReadOnlyDocumentCacheDelegate) {
    self.delegate = delegate
  }

  /// Close all documents.
  deinit {
    for document in nameToDocumentMap.values {
      document.close(completionHandler: nil)
    }
  }

  public weak var delegate: ReadOnlyDocumentCacheDelegate?

  /// Holds the association of names to documents.
  private var nameToDocumentMap = [String: UIDocument]()

  /// Gets the *open* document associated with this name.
  ///
  /// - parameter name: The name of the document to retrieve.
  /// - parameter completion: Routine called on the main thread with the open UIDocument, if it
  ///                         could be opened, or nil if it couldn't.
  public func document(for name: String, completion: @escaping (UIDocument?) -> Void) {
    if let existingDocument = nameToDocumentMap[name] {
      completion(existingDocument)
      return
    }
    guard let document = delegate?.documentCache(self, documentFor: name) else {
      completion(nil)
      return
    }
    completion(document)
  }
}
