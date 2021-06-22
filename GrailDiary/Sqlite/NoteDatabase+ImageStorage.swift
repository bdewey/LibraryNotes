// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

public protocol ImageStorage: MarkupFormattingTextViewImageStorage {
  /// Given the key returned from `markdownEditingTextView(_:store:suffix:)`, retrieve the corresponding image data.
  func retrieveImageDataForKey(_ key: String) throws -> Data
}

public struct ImageReplacementFormatter: ParsedAttributedStringFormatter {
  public init(_ imageStorage: ImageStorage) {
    self.imageStorage = imageStorage
  }

  let imageStorage: ImageStorage

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
    do {
      let imageData = try imageStorage.retrieveImageDataForKey(target)
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

public struct BoundNote {
  let identifier: Note.Identifier
  let database: NoteDatabase
}

extension BoundNote: ImageStorage {
  public func storeImageData(_ imageData: Data, type: UTType, key: String?) throws -> String {
    let imageKey = try database.writeAssociatedData(imageData, noteIdentifier: identifier, role: "embeddedImage", type: type, key: key)
    return "![](\(imageKey))"
  }

  public func retrieveImageDataForKey(_ key: String) throws -> Data {
    return try database.readAssociatedData(from: identifier, key: key)
  }
}

public extension ParsedAttributedString.Settings {
  func renderingImages(from imageStorage: ImageStorage) -> Self {
    var copy = self
    copy.formatters[.image] = AnyParsedAttributedStringFormatter(ImageReplacementFormatter(imageStorage))
    return copy
  }
}

public extension NoteDatabase {
  // TODO: Remove AssetRecord from the schema
  /// Stores arbitrary data in the database.
  /// - Parameters:
  ///   - data: The asset data to store
  ///   - key: A unique key for the data
  /// - Throws: .databaseIsNotOpen
  /// - Returns: The key??
  @available(*, deprecated, message: "Use writeAssociatedData: instead")
  func storeAssetData(_ data: Data, key: String) throws -> String {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.write { db in
      let asset = AssetRecord(id: key, data: data)
      try asset.save(db)
      return key
    }
  }

  /// Gets arbitrary data back from
  /// - Parameter key: Key for the asset data to retrieve.
  /// - Throws: .databaseIsNotOpen, .noSuchAsset
  /// - Returns: The data corresponding with `key`
  func retrieveAssetDataForKey(_ key: String) throws -> Data {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    guard let record = try dbQueue.read({ db in
      try AssetRecord.filter(key: key).fetchOne(db)
    }) else {
      throw Error.noSuchAsset
    }
    return record.data
  }

  func writeAssociatedData(
    _ data: Data,
    noteIdentifier: Note.Identifier,
    role: String,
    type: UTType,
    key: String? = nil
  ) throws -> String {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    let actualKey = key ?? ["./" + data.sha1Digest(), type.preferredFilenameExtension].compactMap { $0 }.joined(separator: ".")
    let binaryRecord = BinaryContentRecord(
      blob: data,
      noteId: noteIdentifier,
      key: actualKey,
      role: role,
      mimeType: type.preferredMIMEType ?? "application/octet-stream"
    )
    try dbQueue.write { db in
      try binaryRecord.save(db)
    }
    return actualKey
  }

  func readAssociatedData(from noteIdentifier: Note.Identifier, key: String) throws -> Data {
    guard let dbQueue = dbQueue else {
      throw Error.databaseIsNotOpen
    }
    return try dbQueue.read { db in
      guard let record = try BinaryContentRecord.fetchOne(
        db,
        key: [BinaryContentRecord.Columns.noteId.rawValue: noteIdentifier, BinaryContentRecord.Columns.key.rawValue: key]
      ) else {
        throw Error.noSuchAsset
      }
      return record.blob
    }
  }
}

// extension NoteDatabase: ImageStorage {
//  public func storeImageData(_ imageData: Data, suffix: String) throws -> String {
//    let key = imageData.sha1Digest() + "." + suffix
//    return try storeAssetData(imageData, key: key)
//  }
//
//  public func retrieveImageDataForKey(_ key: String) throws -> Data {
//    return try retrieveAssetDataForKey(key)
//  }
// }
