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

public extension ParsedAttributedString.Style {
  func renderingImages(from imageStorage: ImageStorage) -> Self {
    var copy = self
    copy.formatters[.image] = AnyParsedAttributedStringFormatter(ImageReplacementFormatter(imageStorage))
    return copy
  }
}
