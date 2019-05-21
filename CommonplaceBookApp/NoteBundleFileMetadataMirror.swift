// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import UIKit

/// This class watches content in a FileMetadataProvider. As content changes, it updates
/// the properties inside the NoteBundleDocument. (Similar to performing continual incremental
/// recompile of source.) Then, based upon those properties, specifically the "title", it may
/// try to rename files in the Metadata provider.
public final class NoteBundleFileMetadataMirror {

  /// Sets up the mirror.
  ///
  /// - precondition: `document` is closed. It will get opened by the mirror.
  /// - precondition: `metadataProvider` must not have a delegate.
  ///                  This instance will be the delegate.
  public init(
    document: NoteBundleDocument,
    metadataProvider: FileMetadataProvider,
    automaticallyRenameFiles: Bool = true
  ) {
    precondition(document.documentState == .closed)
    precondition(metadataProvider.delegate == nil)
    self.document = document
    self.metadataProvider = metadataProvider

    document.addObserver(self)
    document.openOrCreate { success in
      DDLogDebug("Opened note bundle: \(success), state = \(document.documentState)")
    }
    metadataProvider.delegate = self
  }

  deinit {
    document.removeObserver(self)
  }

  private let document: NoteBundleDocument
  private let metadataProvider: FileMetadataProvider

  /// Responds to changes in document state.
  private func documentStateChanged() {
    guard !document.documentState.contains(.closed) else { return }
    if document.documentState.contains(.inConflict) {
      DDLogError("Conflict! Dont handle that yet :-(")
    } else if document.documentState.contains(.editingDisabled) {
      DDLogError("Editing disabled. Why?")
    } else {
      processMetadata(metadataProvider.fileMetadata)
    }
  }
}

/// Extensions for making the file names in the MetadataProvider match the properties
/// extracted from those files and stored in the NoteBundle.
public extension NoteBundleFileMetadataMirror {
  /// The list of pages where the name does not match the desired base name.
  /// The keys are existing file names. The values are desired *base* names
  /// (no extensions, no uniqifiers).
  var desiredBaseNameForPage: [String: String] {
    var results = [String: String]()
    for (fileName, properties) in document.noteBundle.pageProperties {
      guard let desiredName = self.desiredBaseFileName(for: properties) else { continue }
      if !fileName.hasPrefix(desiredName) {
        results[fileName] = desiredName
      }
    }
    return results
  }

  func performRenames(_ desiredBaseNameForPage: [String: String]) throws {
    guard !desiredBaseNameForPage.isEmpty else { return }

    // HACK: Avoid processing metadata provider notifications until this batch is done
    precondition(metadataProvider.delegate === self)
    metadataProvider.delegate = nil
    defer { metadataProvider.delegate = self }

    let successfulRenames = renameFileMetadata(desiredBaseNameForPage: desiredBaseNameForPage)
      .compactMapValues { try? $0.get() }
    document.performRenames(successfulRenames)
  }

  /// Given a mapping of existing file name to desired base name (no extension), determines
  /// an actual unique file name and does the rename. For all successful renames, returns
  /// the actual file name in the result.
  private func renameFileMetadata(desiredBaseNameForPage: [String: String]) -> [String: Result<String, Error>] {
    var results = [String: Result<String, Error>]()
    for (existingPage, baseName) in desiredBaseNameForPage {
      let pathExtension = (existingPage as NSString).pathExtension
      let newName = FileNameGenerator(baseName: baseName, pathExtension: pathExtension)
        .firstName(notIn: metadataProvider)
      DDLogInfo("Renaming \(existingPage) to \(newName)")
      results[existingPage] = Result { () throws -> String in
        try metadataProvider.renameMetadata(FileMetadata(fileName: existingPage), to: newName)
        return newName
      }
    }
    return results
  }

  private static let commonWords: Set<String> = [
    "of",
    "the",
    "a",
    "an",
  ]

  private static let allowedNameCharacters: CharacterSet = {
    var allowedNameCharacters = CharacterSet.alphanumerics
    allowedNameCharacters.insert(" ")
    return allowedNameCharacters
  }()

  /// The "desired" base file name for this page.
  ///
  /// - note: The desired name comes from the first 5 words of the title, excluding
  ///         common words like "of", "a", "the", concatenated and separated by hyphens.
  private func desiredBaseFileName(for properties: NoteBundlePageProperties) -> String? {
    let sanitizedTitle = plainTextTitle(for: properties)
      .strippingLeadingAndTrailingWhitespace
      .filter {
        $0.unicodeScalars.count == 1
          && NoteBundleFileMetadataMirror.allowedNameCharacters.contains($0.unicodeScalars.first!)
      }
    guard !sanitizedTitle.isEmpty else { return nil }
    return sanitizedTitle
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace })
      .map { String($0) }
      .filter { !NoteBundleFileMetadataMirror.commonWords.contains($0) }
      .prefix(5)
      .joined(separator: "-")
  }

  /// Title with all markdown characters removed
  private func plainTextTitle(for properties: NoteBundlePageProperties) -> String {
    return document.noteBundle.parsingRules
      .parse(properties.title)
      .reduce(into: "") { string, node in
        string.append(MarkdownAttributedStringRenderer.textOnly.render(node: node).string)
      }
  }
}

extension NoteBundleFileMetadataMirror: FileMetadataProviderDelegate {
  public func fileMetadataProvider(
    _ provider: FileMetadataProvider,
    didUpdate metadata: [FileMetadata]
  ) {
    processMetadata(metadata)
  }

  private func processMetadata(_ metadata: [FileMetadata]) {
    guard document.documentState.intersection([.closed, .editingDisabled]).isEmpty else { return }
    let models = metadata
    for fileMetadata in models {
      fileMetadata.downloadIfNeeded(in: metadataProvider.container)
      document.updatePage(for: fileMetadata, in: metadataProvider, completion: nil)
    }
  }
}

extension NoteBundleFileMetadataMirror: NoteBundleDocumentObserver {
  public func noteBundleDocument(_ document: NoteBundleDocument, didChangeToState state: UIDocument.State) {
    documentStateChanged()
  }

  public func noteBundleDocumentDidUpdatePages(_ document: NoteBundleDocument) {
    // nothing
  }
}
