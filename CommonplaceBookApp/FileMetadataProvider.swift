// Copyright © 2017-present Brian's Brain. All rights reserved.

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
public protocol FileMetadataProvider: class {
  var container: URL { get }

  /// The current array of metadata.
  var fileMetadata: [FileMetadata] { get }

  func queryForCurrentFileMetadata(completion: @escaping ([FileMetadata]) -> Void)

  /// Delegate that can receive notifications when `fileMetadata` changes.
  var delegate: FileMetadataProviderDelegate? { get set }

  /// Gets the EditableDocument that corresponds to a particular piece of metadata.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument?

  /// Delete an item.
  func delete(_ metadata: FileMetadata) throws

  /// Tests if there is currently an item with a given path component in this container.
  func itemExists(with pathComponent: String) throws -> Bool

  /// Renames an item associated with metadata.
  func renameMetadata(_ metadata: FileMetadata, to name: String) throws
}

enum FileMetadataProviderError: Error {
  case cannotGetDocument
  case cannotOpenDocument
}

/// I/O routines that work for all implementations of FileMetadataProvider
public extension FileMetadataProvider {
  /// Default implementation of editableDocument -- will work for any FileMetadataProvider
  /// that is named by URLs that a UIDocument can open.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
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

  /// Loads the text from a specific FileMetadata.
  ///
  /// - note: FileMetadata may refer to either a plain text file -or- a textbundle,
  ///         and this method knows how to read from either.
  ///
  /// - parameter fileMetadata: The FileMetadata specifying the file to read from.
  /// - parameter completion: Completion block with the result of reading.
  func loadText(
    from fileMetadata: FileMetadata,
    completion: @escaping (Result<String>) -> Void
  ) {
    guard let document = editableDocument(for: fileMetadata) else {
      completion(.failure(FileMetadataProviderError.cannotGetDocument))
      return
    }
    document.open { success in
      guard success else {
        completion(.failure(FileMetadataProviderError.cannotOpenDocument))
        return
      }
      let textResult = document.currentTextResult.flatMap { $0.value }
      document.close(completionHandler: nil)
      completion(textResult)
    }
  }
}
