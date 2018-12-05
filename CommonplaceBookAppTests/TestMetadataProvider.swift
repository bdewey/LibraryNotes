// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import Foundation
import MiniMarkdown

/// Serves in-memory copy of FileMetadata object that are backed by TestEditableDocument
/// instances.
final class TestMetadataProvider: FileMetadataProvider {

  /// A subset of `FileMetadata` that also includes file contents.
  struct FileInfo {
    let fileName: String
    let contents: String
  }

  /// Designated initializer.
  ///
  /// - parameter fileMetadata: The file metadata in this collection.
  init(fileInfo: [FileInfo]) {
    self.fileNameToMetadata = fileInfo.reduce(
      into: [String: FileMetadata](),
      { $0[$1.fileName] = FileMetadata(fileName: $1.fileName) }
    )
    self.fileContents = fileInfo.reduce(into: [String: String](), { $0[$1.fileName] = $1.contents })
  }

  func addFileInfo(_ fileInfo: FileInfo) {
    self.fileNameToMetadata[fileInfo.fileName] = FileMetadata(fileName: fileInfo.fileName)
    self.fileContents[fileInfo.fileName] = fileInfo.contents
    delegate?.fileMetadataProvider(self, didUpdate: self.fileMetadata)
  }

  /// A fake URL for this container.
  let container = URL(string: "test://metadata")!

  /// Map of file name to file metadata (includes things like modified time)
  var fileNameToMetadata: [String: FileMetadata]

  var fileMetadata: [FileMetadata] { return Array(fileNameToMetadata.values) }

  /// Map of file name to file contents
  var fileContents: [String: String]

  /// Get DocumentProperties for all of the FileMetadata.
  var documentProperties: [DocumentProperties] {
    let parsingRules = ParsingRules()
    return fileNameToMetadata.values.map {
      let text = fileContents[$0.fileName] ?? ""
      return DocumentProperties(fileMetadata: $0, nodes: parsingRules.parse(text))
    }
  }

  /// Gets `documentProperties` as a serialized JSON string.
  var documentPropertiesJSON: String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    let data = (try? encoder.encode(documentProperties)) ?? Data()
    return String(data: data, encoding: .utf8) ?? ""
  }

  /// A delegate to notify in the event of changes.
  /// - note: Currently unused as the metadata in this collection are immutable.
  weak var delegate: FileMetadataProviderDelegate?

  /// Get an editable document for a file metadata.
  /// - note: Currently provides only dummy content. TODO: Associate different text with
  ///         different metadata.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
    let contents = fileContents[metadata.fileName] ?? ""
    return TestEditableDocument(contents)
  }
}
