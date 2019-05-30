// Copyright © 2017-present Brian's Brain. All rights reserved.

import TextBundleKit
import UIKit

/// An object that knows how to manipulate documents in the Commonplace Book.
public protocol DocumentFactory {
  /// The underlying document type. Probably a UIDocument subclass.
  associatedtype Document

  /// True if the user allows us to store documents in iCloud.
  var useCloud: Bool { get }

  /// Asynchronously opens a document.
  ///
  /// - parameter url: The URL to open.
  /// - parameter completion: A completion routine to call with the document.
  func openDocument(at url: URL, completion: @escaping (Result<Document>) -> Void)

//  /// Creates a new document.
//  ///
//  /// - parameter url: The URL where to place the new document.
//  /// - parameter completion: The completion routine to call with the newly created document.
//  func createNewDocument(at url: URL, completion: @escaping (Result<Document>) -> Void)
//
  /// Merge two versions of a document.
  ///
  /// - parameter source: The source document. This contains new changes.
  /// - parameter destination: The destination document, that receives the changes from `source`.
  func merge(source: Document, destination: Document)

  /// Deletes a document.
  ///
  /// - parameter document: The document to delete.
  func delete(_ document: Document)
}

/// Manages documents in Commonplace Book, a common central repository.
public final class CommonplaceBook {
  private static let containerIdentifier = "iCloud.org.brians-brain.commonplace-book"

  /// Asynchronously opens a document.
  ///
  /// This routine handles all of the work of determining if there are local changes, iCloud
  /// changes, and driving the merging of two verisons of a document (if required).
  ///
  /// - parameter pathComponent: The relative path within Commonplace Book for the document.
  /// - parameter factory: The DocumentFactory that knows how to actually create a document model.
  /// - parameter completion: The completion routine that gets called with the resulting document.
  public static func openDocument<Document, DocumentFactoryType: DocumentFactory>(
    at pathComponent: String,
    using factory: DocumentFactoryType,
    completion: @escaping (Result<Document>) -> Void
  ) where DocumentFactoryType.Document == Document {
    let useCloud = factory.useCloud
    let localURL = localContainerURL.appendingPathComponent(pathComponent)
    let localExists = FileManager.default.fileExists(atPath: localURL.path)
    if FileManager.default.ubiquityIdentityToken == nil {
      factory.openDocument(at: localURL, completion: completion)
      return
    }
    DispatchQueue.global(qos: .default).async {
      let cloudURL = self.ubiquityContainerURL.appendingPathComponent(pathComponent)
      let cloudExists = FileManager.default.isUbiquitousItem(at: cloudURL)
      DispatchQueue.main.async {
        switch (useCloud, localExists, cloudExists) {
        case (false, _, false):
          // Happy case: Not using cloud & nothing in the cloud.
          factory.openDocument(at: localURL, completion: completion)
        case (true, false, _):
          // Happy case: Using cloud & there's nothing local.
          factory.openDocument(at: cloudURL, completion: completion)
        case (false, false, true):
          // We're not using cloud, but the only thing is the cloud document. Make it local then go.
          self.setUbiquitous(false, itemAt: cloudURL, destinationURL: localURL, completion: { error in
            if let error = error {
              completion(.failure(error))
            } else {
              factory.openDocument(at: localURL, completion: completion)
            }
          })
        case (false, true, true):
          // We're not using cloud, but there's a copy in both places. Merge cloud to local & delete cloud.
          self.merge(source: cloudURL, destination: localURL, factory: factory, completion: completion)
        case (true, true, false):
          // We're using cloud, but we only have a local copy.
          self.setUbiquitous(true, itemAt: localURL, destinationURL: cloudURL, completion: { error in
            if let error = error {
              completion(.failure(error))
            } else {
              factory.openDocument(at: cloudURL, completion: completion)
            }
          })
        case (true, true, true):
          // We're using cloud with a copy in both places.
          self.merge(source: localURL, destination: cloudURL, factory: factory, completion: completion)
        }
      }
    }
  }

  /// Asynchronously sets whether the item at the specified URL should be stored in the cloud.
  ///
  /// - parameter ubiquitious: Specify true to move the item to iCloud or false to remove it
  ///             from iCloud (if it is there currently).
  /// - parameter itemAt: Specify the URL of the item (file or directory) that you want to
  ///             store in iCloud.
  /// - parameter destinationURL: the URL for the item in the cloud.
  /// - parameter completion: A callback that will get invoked on completion of the operation.
  private static func setUbiquitous(
    _ ubiquitous: Bool,
    itemAt: URL,
    destinationURL: URL,
    completion: @escaping (Error?) -> Void
  ) {
    DispatchQueue.global(qos: .default).async {
      var fileError: Error?
      do {
        try FileManager.default.setUbiquitous(ubiquitous, itemAt: itemAt, destinationURL: destinationURL)
      } catch {
        fileError = error
      }
      DispatchQueue.main.async {
        completion(fileError)
      }
    }
  }

  /// Merge two versions of a document.
  ///
  /// - parameter source: The URL for the source version of the document.
  /// - parameter destination: The URL for the destination version of the document.
  /// - parameter factory: The object that can actually perform the merge.
  /// - parameter completion: A function that will get called on completion of the merge.
  private static func merge<Document, DocumentFactoryType: DocumentFactory>(
    source: URL,
    destination: URL,
    factory: DocumentFactoryType,
    completion: @escaping (Result<Document>) -> Void
  ) where DocumentFactoryType.Document == Document {
    factory.openDocument(at: source) { sourceResult in
      factory.openDocument(at: destination, completion: { destinationResult in
        switch (sourceResult, destinationResult) {
        case (.success(let sourceDocument), .success(let destinationDocument)):
          factory.merge(source: sourceDocument, destination: destinationDocument)
          factory.delete(sourceDocument)
          completion(.success(destinationDocument))
        default:
          completion(destinationResult)
        }
      })
    }
  }

  /// The ubiquity container identifier.
  ///
  /// - warning: This can be expensive to get, so only access on a background thread.
  public static var ubiquityContainerURL: URL {
    assert(!Thread.isMainThread)
    return FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)!.appendingPathComponent("Documents")
  }

  /// The URL of the local document container.
  public static var localContainerURL: URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
  }
}
