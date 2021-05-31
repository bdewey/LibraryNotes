// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct Note: Equatable {
  public init(
    creationTimestamp: Date,
    timestamp: Date,
    hashtags: [String],
    referencedImageKeys: [String],
    title: String, text: String? = nil,
    reference: Note.Reference? = nil,
    folder: String? = nil,
    summary: String? = nil,
    promptCollections: [Note.ContentKey: PromptCollection]
  ) {
    self.creationTimestamp = creationTimestamp
    self.timestamp = timestamp
    self.hashtags = hashtags
    self.referencedImageKeys = referencedImageKeys
    self.title = title
    self.text = text
    self.reference = reference
    self.folder = folder
    self.summary = summary
    self.promptCollections = promptCollections
  }

  /// Identifies a note.
  public typealias Identifier = String

  /// Identifies content within a note (currently, just prompts, but can be extended to other things)
  public typealias ContentKey = String

  public var creationTimestamp: Date

  /// Last modified time of the page.
  public var timestamp: Date

  /// Hashtags present in the page.
  /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
  public var hashtags: [String]

  /// Images referenced by this note.
  public var referencedImageKeys: [String]

  public static let coverImageKey: String = "coverImage"

  /// Title of the page. May include Markdown formatting.
  public var title: String

  /// What this note is "about."
  public enum Reference: Equatable {
    case book(Book)
    case webPage(URL)
  }

  public var text: String?
  public var reference: Reference?
  public var folder: String?

  /// A short summary of the contents of this note. This shows up in the note list.
  public var summary: String?
  public var promptCollections: [ContentKey: PromptCollection]

  public static func == (lhs: Note, rhs: Note) -> Bool {
    return
      abs(lhs.timestamp.timeIntervalSince1970 - rhs.timestamp.timeIntervalSince1970) < 0.001 &&
      lhs.hashtags == rhs.hashtags &&
      lhs.title == rhs.title &&
      lhs.text == rhs.text &&
      lhs.reference == rhs.reference &&
      lhs.folder == rhs.folder &&
      Set(lhs.promptCollections.keys) == Set(rhs.promptCollections.keys)
  }
}
