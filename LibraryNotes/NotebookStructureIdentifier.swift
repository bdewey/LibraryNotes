// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Identifies the subset of notebook pages currently being viewed or queried.
public enum NotebookStructureIdentifier: Hashable, CustomStringConvertible, RawRepresentable {
  case trash
  case hashtag(String)
  case read

  /// The raw value is used to serialize the focused element for state restoration.
  public init?(rawValue: String) {
    switch rawValue {
    case "##all##":
      self = .read
    case "##trash##":
      self = .trash
    default:
      self = .hashtag(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .trash:
      "##trash##"
    case .read:
      "##all##"
    case .hashtag(let hashtag):
      hashtag
    }
  }

  public var description: String {
    switch self {
    case .trash: "Trash"
    case .read: "My Books"
    case .hashtag(let hashtag): String(hashtag.split(separator: "/").last ?? "")
    }
  }

  public var longDescription: String {
    switch self {
    case .trash: "Trash"
    case .read: "My Books"
    case .hashtag(let hashtag): hashtag
    }
  }

  public var predefinedFolder: PredefinedFolder? {
    switch self {
    case .hashtag, .read: nil
    case .trash: .recentlyDeleted
    }
  }

  public var hashtag: String? {
    guard case .hashtag(let hashtag) = self else {
      return nil
    }
    return hashtag
  }

  /// A filter function that returns true if `metadata` is included in this structure.
  public func filterBookNoteMetadata(tuple: (key: String, value: BookNoteMetadata)) -> Bool {
    let metadata = tuple.value
    switch self {
    case .hashtag(let hashtag):
      return metadata.tags.contains(hashtag) || (metadata.book?.tags?.contains(hashtag) ?? false)
    case .trash:
      return metadata.folder == PredefinedFolder.recentlyDeleted.rawValue
    default:
      return metadata.folder != PredefinedFolder.recentlyDeleted.rawValue
    }
  }
}
