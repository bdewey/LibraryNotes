// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import Foundation

/// Serves in-memory copy of FileMetadata object that are backed by TestEditableDocument
/// instances.
struct TestMetadataProvider: FileMetadataProvider {

  /// A subset of `FileMetadata` that also includes file contents.
  struct FileInfo {
    let fileName: String
    let contents: String
  }

  /// Designated initializer.
  ///
  /// - parameter fileMetadata: The file metadata in this collection.
  init(fileInfo: [FileInfo]) {
    self.fileMetadata = fileInfo.map { FileMetadata(fileName: $0.fileName) }
    self.fileContents = fileInfo.reduce(into: [String: String](), { $0[$1.fileName] = $1.contents })
  }

  /// A fake URL for this container.
  let container = URL(string: "test://metadata")!

  /// The file metadata provided by this structure.
  let fileMetadata: [FileMetadata]

  let fileContents: [String: String]

  /// A delegate to notify in the event of changes.
  /// - note: Currently unused as the metadata in this collection are immutable.
  weak var delegate: FileMetadataProviderDelegate?

  /// Get an editable document for a file metadata.
  /// - note: Currently provides only dummy content. TODO: Associate different text with
  ///         different metadata.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
    guard let contents = fileContents[metadata.fileName] else { return nil }
    return TestEditableDocument(contents)
  }
}
