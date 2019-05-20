// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import IGListKit

/// Metadata about pages in a NoteBundle.
public struct NoteBundlePageProperties: Codable, Equatable {
  /// SHA-1 digest of the contents of the page.
  public let sha1Digest: String

  /// Last modified time of the page.
  public let timestamp: Date

  /// Hashtags present in the page.
  public let hashtags: [String]

  /// Title of the page. May include Markdown formatting.
  public let title: String

  /// IDs of all card templates in the page.
  public let cardTemplates: [String]
}

/// Wrapper around PageProperties for IGListKit.
public final class NoteBundlePagePropertiesListDiffable: ListDiffable {
  public let fileMetadata: FileMetadata

  /// The wrapped PageProperties.
  public private(set) var properties: NoteBundlePageProperties

  /// How many cards are eligible for study in this page.
  public private(set) var cardCount: Int

  /// Designated initializer.
  public init(fileMetadata: FileMetadata, properties: NoteBundlePageProperties, cardCount: Int) {
    self.fileMetadata = fileMetadata
    self.properties = properties
    self.cardCount = cardCount
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return fileMetadata.fileName as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? NoteBundlePagePropertiesListDiffable else { return false }
    return properties == otherWrapper.properties &&
      cardCount == otherWrapper.cardCount &&
      fileMetadata == otherWrapper.fileMetadata
  }
}

/// Debuggability extensions for PagePropertiesListDiffable.
extension NoteBundlePagePropertiesListDiffable: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { return String(describing: properties) }
  public var debugDescription: String {
    return "DocumentPropertiesListDiffable \(Unmanaged.passUnretained(self).toOpaque()) "
      + String(describing: properties)
  }
}
