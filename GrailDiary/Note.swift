// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct Note: Equatable {
  /// Identifies a note.
  public typealias Identifier = String

  /// Identifies content within a note (currently, just prompts, but can be extended to other things)
  public typealias ContentKey = String

  public struct Metadata: Hashable {
    public var creationTimestamp: Date

    /// Last modified time of the page.
    public var timestamp: Date

    /// Hashtags present in the page.
    /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
    public var hashtags: [String]

    /// Title of the page. May include Markdown formatting.
    public var title: String

    public init(
      creationTimestamp: Date,
      timestamp: Date = Date(),
      hashtags: [String] = [],
      title: String = ""
    ) {
      self.creationTimestamp = creationTimestamp
      self.timestamp = timestamp
      self.hashtags = hashtags
      self.title = title
    }

    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
      return
        abs(lhs.timestamp.timeIntervalSince1970 - rhs.timestamp.timeIntervalSince1970) < 0.001 &&
        lhs.hashtags == rhs.hashtags &&
        lhs.title == rhs.title
    }
  }

  /// What this note is "about."
  public enum Reference: Equatable {
    case webPage(URL)
  }

  public var metadata: Metadata
  public var text: String?
  public var reference: Reference?
  public var promptCollections: [ContentKey: PromptCollection]

  public init(
    metadata: Metadata = Metadata(creationTimestamp: Date()),
    text: String? = nil,
    reference: Reference? = nil,
    promptCollections: [ContentKey: PromptCollection] = [:]
  ) {
    self.metadata = metadata
    self.text = text
    self.reference = reference
    self.promptCollections = promptCollections
  }

  public static func == (lhs: Note, rhs: Note) -> Bool {
    if lhs.metadata != rhs.metadata || lhs.text != rhs.text || lhs.reference != rhs.reference {
      return false
    }
    let lhsIdentifiers = Set(lhs.promptCollections.keys)
    let rhsIdentifiers = Set(rhs.promptCollections.keys)
    return lhsIdentifiers == rhsIdentifiers
  }
}
