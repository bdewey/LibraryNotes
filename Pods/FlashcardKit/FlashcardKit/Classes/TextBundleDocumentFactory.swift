// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import TextBundleKit

// TODO: Move this to textbundle-swift? It's generic to textbundle, and shouldn't go into each app,
// but also specific to CommonplaceBook.

/// Knows how to open TextBundleDocument documents from the CommonplaceBook document store.
public struct TextBundleDocumentFactory: DocumentFactory {

  /// Initializer.
  init(useCloud: Bool) {
    self.useCloud = useCloud
  }

  /// If true, CommonplaceBook will prefer to get the document from cloud storage.
  /// If false, it will prefer to get the document from local storage.
  public var useCloud: Bool

  /// Generic "file is corrupt" error if we can't open the doc and can't figure out why.
  static let corruptFileError = NSError(
    domain: NSCocoaErrorDomain,
    code: NSFileReadCorruptFileError,
    userInfo: [:]
  )

  /// Allocates a TextBundleDocument and opens it.
  ///
  /// - parameter url: The URL of the document to open.
  /// - parameter completion: Completion routine to call either with the open document, or
  ///                         an error code indicating why the document couldn't be opened.
  public func openDocument(
    at url: URL,
    completion: @escaping (Result<TextBundleDocument>) -> Void
    ) {
    let document = TextBundleDocument(fileURL: url)
    document.open { (success) in
      if success {
        completion(.success(document))
      } else {
        // Try creating a new document.
        document.save(to: url, for: .forCreating, completionHandler: { (createSuccess) in
          if createSuccess {
            completion(.success(document))
          } else {
            let error = document.previousError ?? TextBundleDocumentFactory.corruptFileError
            completion(.failure(error))
          }
        })
      }
    }
  }

  /// If the local & cloud versions of the document conflict, this method resolves them.
  public func merge(source: TextBundleDocument, destination: TextBundleDocument) {
    fatalError("merge not implemented")
  }

  /// Deletes the document.
  public func delete(_ document: TextBundleDocument) {
    try? FileManager.default.removeItem(at: document.fileURL)
  }
}

