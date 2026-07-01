// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import Foundation

public extension PersonNameComponents {
  func compare(to other: PersonNameComponents) -> ComparisonResult {
    if let familyName, let otherFamilyName = other.familyName {
      let result = familyName.compare(otherFamilyName, options: [.diacriticInsensitive, .caseInsensitive])
      if result != .orderedSame { return result }
    }
    if let givenName, let otherGivenName = other.givenName {
      return givenName.compare(otherGivenName)
    }
    return .orderedSame
  }
}

extension PersonNameComponents?: @retroactive Comparable {
  public static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
    switch (lhs, rhs) {
    case (.none, .some):
      // No name before name
      true
    case (.some, .none):
      false
    case (.none, .none):
      false
    case (.some(let lhs), .some(let rhs)):
      lhs.compare(to: rhs) == .orderedAscending
    }
  }
}
