// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation

public struct Note {
  public init(
    metadata: BookNoteMetadata,
    referencedImageKeys: [String],
    text: String? = nil,
    promptCollections: [Note.ContentKey: PromptCollection]
  ) {
    self.metadata = metadata
    self.referencedImageKeys = referencedImageKeys
    self.text = text
    self.promptCollections = promptCollections
  }

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
    let metadata = BookNoteMetadata(
      title: title,
      summary: summary,
      creationTimestamp: creationTimestamp,
      modifiedTimestamp: timestamp,
      tags: hashtags,
      folder: folder,
      book: nil
    )
    self.init(metadata: metadata, referencedImageKeys: referencedImageKeys, text: text, promptCollections: promptCollections)
  }

  /// Identifies a note.
  public typealias Identifier = String

  /// Identifies content within a note (currently, just prompts, but can be extended to other things)
  public typealias ContentKey = String

  public var metadata: BookNoteMetadata

  /// Images referenced by this note.
  public var referencedImageKeys: [String]

  /// What this note is "about."
  public enum Reference: Equatable {
    case book(AugmentedBook)
    case webPage(URL)

    var book: AugmentedBook? {
      if case .book(let book) = self {
        return book
      } else {
        return nil
      }
    }
  }

  public var text: String?
  public var promptCollections: [ContentKey: PromptCollection]
}

extension Note: Equatable {
  public static func == (lhs: Note, rhs: Note) -> Bool {
    lhs.metadata == rhs.metadata &&
      lhs.referencedImageKeys == rhs.referencedImageKeys &&
      lhs.text == rhs.text &&
      lhs.promptCollections.mapValues { $0.rawValue } == rhs.promptCollections.mapValues { $0.rawValue }
  }
}
