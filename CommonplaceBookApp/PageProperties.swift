// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import IGListKit
import Yams

/// Metadata about pages in a NoteBundle.
public struct PageProperties: Codable, Equatable {
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

  init(
    sha1Digest: String,
    timestamp: Date,
    hashtags: [String],
    title: String,
    cardTemplates: [String]
  ) {
    self.sha1Digest = sha1Digest
    self.timestamp = timestamp
    self.hashtags = hashtags
    self.title = title
    self.cardTemplates = cardTemplates
  }

  func makeSnippet() throws -> TextSnippet {
    let text = try YAMLEncoder().encode(self)
    return TextSnippet(text)
  }

  init(_ snippet: TextSnippet) throws {
    self = try YAMLDecoder().decode(PageProperties.self, from: snippet.text)
  }
}

/// Wrapper around PageProperties for IGListKit.
public final class NoteBundlePagePropertiesListDiffable: ListDiffable {
  public let pageKey: String

  /// The wrapped PageProperties.
  public private(set) var properties: PageProperties

  /// How many cards are eligible for study in this page.
  public private(set) var cardCount: Int

  /// Designated initializer.
  public init(pageKey: String, properties: PageProperties, cardCount: Int) {
    self.pageKey = pageKey
    self.properties = properties
    self.cardCount = cardCount
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return pageKey as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? NoteBundlePagePropertiesListDiffable else { return false }
    return properties == otherWrapper.properties &&
      cardCount == otherWrapper.cardCount &&
      pageKey == otherWrapper.pageKey
  }
}

/// Debuggability extensions for PagePropertiesListDiffable.
extension NoteBundlePagePropertiesListDiffable:
  CustomStringConvertible,
  CustomDebugStringConvertible {
  public var description: String { return String(describing: properties) }
  public var debugDescription: String {
    return "DocumentPropertiesListDiffable \(Unmanaged.passUnretained(self).toOpaque()) "
      + String(describing: properties)
  }
}
