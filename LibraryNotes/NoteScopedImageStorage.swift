// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

/// Stores and retrieves images in a ``NoteDatabase`` that are scoped to a specific note.
@MainActor
public struct NoteScopedImageStorage {
  /// The note for which the images are stored.
  public let identifier: Note.Identifier

  /// The database for storing the images.
  public let database: NoteDatabase

  public func storeImageData(_ imageData: Data, type: UTType) throws -> NoteDatabaseKey {
    let actualKey = NoteDatabaseKey.asset(assetKey: imageData.sha1Digest(), assetType: type)
    let mimeType = type.preferredMIMEType ?? "application/octet-stream"
    try database.writeValue(
      .blob(mimeType: mimeType, blob: imageData),
      noteIdentifier: identifier,
      key: actualKey
    )
    return actualKey
  }

  public func storeCoverImage(_ imageData: Data, type: UTType) throws {
    let mimeType = type.preferredMIMEType ?? "application/octet-stream"
    try database.writeValue(
      .blob(mimeType: mimeType, blob: imageData),
      noteIdentifier: identifier,
      key: .coverImage
    )
  }

  public func retrieveImageDataForKey(_ key: NoteDatabaseKey) throws -> Data {
    guard let data = try database.read(noteIdentifier: identifier, key: key).resolved(with: .lastWriterWins)?.blob else {
      throw NoteDatabaseError.noSuchAsset
    }
    return data
  }
}

extension NoteScopedImageStorage: MarkupFormattingTextViewImageStorage {
  public func storeImageData(_ imageData: Data, type: UTType) throws -> String {
    let key: NoteDatabaseKey = try storeImageData(imageData, type: type)
    return "![](\(key.rawValue))"
  }
}

extension NoteScopedImageStorage: ParsedAttributedStringFormatter {
  public func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    var attributes = currentAttributes
    let anchoredNode = AnchoredNode(node: node, startIndex: offset)
    guard let targetNode = anchoredNode.first(where: { $0.type == .linkTarget }) else {
      attributes.color = .quaternaryLabel
      return (attributes, nil)
    }
    let targetChars = buffer[targetNode.range]
    let target = String(utf16CodeUnits: targetChars, count: targetChars.count)
    let key = NoteDatabaseKey(rawValue: target)
    do {
      let imageData = try retrieveImageDataForKey(key)
      // TODO: What's the right image width?
      if let image = imageData.image(maxSize: 200) {
        let attachment = NSTextAttachment()
        attachment.image = image
        attributes.attachment = attachment
        return (attributes, Array("\u{fffc}".utf16))
      }
    } catch {
      Logger.shared.error("Unexpected error getting image data: \(error)")
    }

    // fallback -- show the markdown code instead of the image
    attributes.color = .quaternaryLabel
    return (attributes, nil)
  }
}

public extension ParsedAttributedString.Style {
  func renderingImages(from imageStorage: NoteScopedImageStorage) -> Self {
    var copy = self
    copy.formatters[.image] = AnyParsedAttributedStringFormatter(imageStorage)
    return copy
  }
}
