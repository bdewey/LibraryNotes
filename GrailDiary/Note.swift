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

  /// Identifies a note.
  public typealias Identifier = String

  /// Identifies content within a note (currently, just prompts, but can be extended to other things)
  public typealias ContentKey = String

  public var metadata: BookNoteMetadata

  /// Images referenced by this note.
  public var referencedImageKeys: [String]

  public static let coverImageKey: String = "coverImage"

  /// What this note is "about."
  public enum Reference: Equatable {
    case book(AugmentedBook)
    case webPage(URL)

    var book: AugmentedBook? {
      if case let .book(book) = self {
        return book
      } else {
        return nil
      }
    }
  }

  public var text: String?
  public var promptCollections: [ContentKey: PromptCollection]
}
