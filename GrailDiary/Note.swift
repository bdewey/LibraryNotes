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

  @available(*, deprecated)
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

  @available(*, deprecated)
  public var timestamp: Date {
    get { metadata.modifiedTimestamp }
    set { metadata.modifiedTimestamp = newValue }
  }

  @available(*, deprecated)
  public var hashtags: [String] {
    get { metadata.tags }
    set { metadata.tags = newValue }
  }

  @available(*, deprecated)
  public var title: String {
    get { metadata.title }
    set { metadata.title = newValue }
  }
}

extension Note: Equatable {
  public static func == (lhs: Note, rhs: Note) -> Bool {
    lhs.metadata == rhs.metadata &&
    lhs.referencedImageKeys == rhs.referencedImageKeys &&
    lhs.text == rhs.text &&
    lhs.promptCollections.mapValues({ $0.rawValue }) == rhs.promptCollections.mapValues({ $0.rawValue })
  }
}
