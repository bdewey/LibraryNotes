// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public struct Note {
  /// Identifies a note.
  public struct Identifier: Hashable, RawRepresentable {
    public let rawValue: String

    public init() {
      self.rawValue = UUID().uuidString
    }

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public struct Metadata {
    /// Last modified time of the page.
    public var timestamp: Date = Date()

    /// Hashtags present in the page.
    /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
    public var hashtags: [String] = []

    /// Title of the page. May include Markdown formatting.
    public var title: String = ""

    public init(
      timestamp: Date = Date(),
      hashtags: [String] = [],
      title: String = ""
    ) {
      self.timestamp = timestamp
      self.hashtags = hashtags
      self.title = title
    }
  }

  public var metadata: Metadata
  public var text: String?
  public var challengeTemplates: [ChallengeTemplate]

  public init(
    metadata: Metadata = Metadata(),
    text: String? = nil,
    challengeTemplates: [ChallengeTemplate] = []
  ) {
    self.metadata = metadata
    self.text = text
    self.challengeTemplates = challengeTemplates
  }
}

extension Note.Identifier: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension Note.Identifier: CustomStringConvertible {
  public var description: String { rawValue }
}

extension Note.Identifier: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
