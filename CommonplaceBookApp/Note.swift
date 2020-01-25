// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public struct Note: Equatable {
  /// Identifies a note.
  public typealias Identifier = FlakeID

  public struct Metadata: Hashable {
    /// Last modified time of the page.
    public var timestamp: Date

    /// Hashtags present in the page.
    /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
    public var hashtags: [String]

    /// Title of the page. May include Markdown formatting.
    public var title: String

    /// Does this note contain text or not?
    public var containsText: Bool

    public init(
      timestamp: Date = Date(),
      hashtags: [String] = [],
      title: String = "",
      containsText: Bool = false
    ) {
      self.timestamp = timestamp
      self.hashtags = hashtags
      self.title = title
      self.containsText = containsText
    }

    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
      return
        abs(lhs.timestamp.timeIntervalSince1970 - rhs.timestamp.timeIntervalSince1970) < 0.001 &&
        lhs.hashtags == rhs.hashtags &&
        lhs.title == rhs.title &&
        lhs.containsText == rhs.containsText
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

  public static func == (lhs: Note, rhs: Note) -> Bool {
    if lhs.metadata != rhs.metadata || lhs.text != rhs.text {
      return false
    }
    let lhsIdentifiers = Set(lhs.challengeTemplates.map { $0.templateIdentifier })
    let rhsIdentifiers = Set(rhs.challengeTemplates.map { $0.templateIdentifier })
    return lhsIdentifiers == rhsIdentifiers
  }
}
