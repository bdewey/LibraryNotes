// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import Yams

/// Metadata about pages in a NoteBundle.
public struct PageProperties: Codable, Hashable {
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
