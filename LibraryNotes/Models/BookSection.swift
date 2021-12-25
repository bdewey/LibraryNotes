// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Sections of the collection view
public enum BookSection: String, Codable {
  case wantToRead
  /// Books we are reading
  case currentlyReading
  /// Books we have read
  case read

  /// Pages that aren't associated with books.
  case other

  /// The sections that hold books.
  public static let bookSections: [BookSection] = [.currentlyReading, .wantToRead, .read]

  var headerText: String {
    switch self {
    case .wantToRead:
      return "Want to read"
    case .currentlyReading:
      return "Currently reading"
    case .read:
      return "Read"
    case .other:
      return "Other"
    }
  }
}
