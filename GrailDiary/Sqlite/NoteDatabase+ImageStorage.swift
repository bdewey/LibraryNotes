// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging

/// A protocol that the text views use to store images on paste
public protocol ImageStorage {
  /// Store image data.
  /// - parameter imageData: The image data to store
  /// - parameter suffix: Image data suffix that identifies the data format (e.g., "jpeg", "png")
  /// - returns: A string key that can locate this image later.
  func storeImageData(_ imageData: Data, suffix: String) throws -> String

  /// Given the key returned from `markdownEditingTextView(_:store:suffix:)`, retrieve the corresponding image data.
  func retrieveImageDataForKey(_ key: String) throws -> Data
}

extension ImageStorage {
  /// A replacement function that will replace an `.image` node with a text attachment containing the image (200px max dimension)
  func imageReplacement(
    node: SyntaxTreeNode,
    startIndex: Int,
    buffer: SafeUnicodeBuffer,
    attributes: inout AttributedStringAttributes
  ) -> [unichar]? {
    let anchoredNode = AnchoredNode(node: node, startIndex: startIndex)
    guard let targetNode = anchoredNode.first(where: { $0.type == .linkTarget }) else {
      attributes.color = .quaternaryLabel
      return nil
    }
    let targetChars = buffer[targetNode.range]
    let target = String(utf16CodeUnits: targetChars, count: targetChars.count)
    do {
      let imageData = try retrieveImageDataForKey(target)
      // TODO: What's the right image width?
      if let image = imageData.image(maxSize: 200) {
        let attachment = NSTextAttachment()
        attachment.image = image
        attributes[.attachment] = attachment
        return Array("\u{fffc}".utf16) // "object replacement character"
      }
    } catch {
      Logger.shared.error("Unexpected error getting image data: \(error)")
    }

    // fallback -- show the markdown code instead of the image
    attributes.color = .quaternaryLabel
    return nil
  }
}

public extension NoteDatabase {
  /// Stores arbitrary data in the database.
  /// - Parameters:
  ///   - data: The asset data to store
  ///   - key: A unique key for the data
  /// - Throws: .databaseIsNotOpen
  /// - Returns: The key??
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
}

extension NoteDatabase: ImageStorage {
  public func storeImageData(_ imageData: Data, suffix: String) throws -> String {
    let key = imageData.sha1Digest() + "." + suffix
    return try storeAssetData(imageData, key: key)
  }

  public func retrieveImageDataForKey(_ key: String) throws -> Data {
    return try retrieveAssetDataForKey(key)
  }
}

private extension Data {
  func image(maxSize: CGFloat) -> UIImage? {
    guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
      return nil
    }
    let options: [NSString: NSObject] = [
      kCGImageSourceThumbnailMaxPixelSize: maxSize as NSObject,
      kCGImageSourceCreateThumbnailFromImageAlways: true as NSObject,
      kCGImageSourceCreateThumbnailWithTransform: true as NSObject,
    ]
    let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?).flatMap { UIImage(cgImage: $0) }
    return image
  }
}
