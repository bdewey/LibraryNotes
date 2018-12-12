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
  init(fileInfo: [FileInfo], parsingRules: ParsingRules) {
    self.fileNameToMetadata = fileInfo.reduce(
      into: [String: FileMetadata](), { $0[$1.fileName] = FileMetadata(fileName: $1.fileName) }
    )
    self.fileContents = fileInfo.reduce(into: [String: String](), { $0[$1.fileName] = $1.contents })
    self.parsingRules = parsingRules
  }

  func addFileInfo(_ fileInfo: FileInfo) {
    if var existingMetadata = fileNameToMetadata[fileInfo.fileName] {
      existingMetadata.contentChangeDate.addTimeInterval(3)
      fileNameToMetadata[fileInfo.fileName] = existingMetadata
    } else {
      fileNameToMetadata[fileInfo.fileName] = FileMetadata(fileName: fileInfo.fileName)
    }
    self.fileContents[fileInfo.fileName] = fileInfo.contents
    delegate?.fileMetadataProvider(self, didUpdate: self.fileMetadata)
  }

  /// A fake URL for this container.
  let container = URL(string: "test://metadata")!

  let parsingRules: ParsingRules

  /// Map of file name to file metadata (includes things like modified time)
  var fileNameToMetadata: [String: FileMetadata]

  var fileMetadata: [FileMetadata] { return Array(fileNameToMetadata.values) }

  /// Map of file name to file contents
  var fileContents: [String: String]

  var contentsChangeListener: ((String, String) -> Void)?

  /// Get DocumentProperties for all of the FileMetadata.
  var documentProperties: [PageProperties] {
    return fileNameToMetadata
      .values
      .filter { $0.fileName != Notebook.cachedPropertiesName }
      .map {
        let text = fileContents[$0.fileName] ?? ""
        return PageProperties(fileMetadata: $0, nodes: parsingRules.parse(text))
      }
  }

  /// Gets `documentProperties` as a serialized JSON string.
  var documentPropertiesJSON: String {
    let data = (try? Notebook.encoder.encode(documentProperties)) ?? Data()
    return String(data: data, encoding: .utf8) ?? ""
  }

  /// Adds "properties.json" that contains cached `DocumentProperties` for all existing
  /// file contents.
  func addPropertiesCache() {
    addFileInfo(FileInfo(fileName: Notebook.cachedPropertiesName, contents: documentPropertiesJSON))
  }

  /// A delegate to notify in the event of changes.
  /// - note: Currently unused as the metadata in this collection are immutable.
  weak var delegate: FileMetadataProviderDelegate?

  /// Get an editable document for a file metadata.
  /// - note: Currently provides only dummy content. TODO: Associate different text with
  ///         different metadata.
  func editableDocument(for metadata: FileMetadata) -> EditableDocument? {
    let contents = fileContents[metadata.fileName] ?? ""
    let document = TestEditableDocument(name: metadata.fileName, text: contents)
    document.delegate = self
    return document
  }

  func delete(_ metadata: FileMetadata) throws {
    fileNameToMetadata[metadata.fileName] = nil
    fileContents[metadata.fileName] = nil
  }
}

extension TestMetadataProvider: TestEditableDocumentDelegate {
  func document(_ document: TestEditableDocument, didUpdate text: String) {
    fileContents[document.name] = text
    contentsChangeListener?(document.name, text)
  }
}
