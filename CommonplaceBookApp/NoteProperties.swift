// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import Yams

/// Metadata about pages in a NoteBundle.
public struct NoteProperties: Codable, Hashable {
  /// SHA-1 digest of the contents of the page.
  public var sha1Digest: String?

  /// Last modified time of the page.
  public var timestamp: Date

  /// Hashtags present in the page.
  /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
  public var hashtags: [String]

  /// Title of the page. May include Markdown formatting.
  public var title: String

  /// IDs of all card templates in the page.
  /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
  public var cardTemplates: [String]

  public func makeSnippet() throws -> TextSnippet {
    let text = try YAMLEncoder().encode(self)
    return TextSnippet(text)
  }

  public init(
    sha1Digest: String? = nil,
    timestamp: Date = Date(),
    hashtags: [String] = [],
    title: String = "",
    cardTemplates: [String] = []
  ) {
    self.sha1Digest = sha1Digest
    self.timestamp = timestamp
    self.hashtags = hashtags.sorted()
    self.title = title
    self.cardTemplates = cardTemplates.sorted()
  }

  /// Construct PageProperties from encoded YAML.
  public init(_ snippet: TextSnippet) throws {
    self = try YAMLDecoder().decode(NoteProperties.self, from: snippet.text)
  }
}
