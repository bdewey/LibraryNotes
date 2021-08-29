//
//  PersonNameComponents+Comparable.swift
//  PersonNameComponents+Comparable
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

public extension PersonNameComponents {
  func compare(to other: PersonNameComponents) -> ComparisonResult {
    if let familyName = self.familyName, let otherFamilyName = other.familyName {
      let result = familyName.compare(otherFamilyName, options: [.diacriticInsensitive, .caseInsensitive])
      if result != .orderedSame { return result }
    }
    if let givenName = self.givenName, let otherGivenName = other.givenName {
      return givenName.compare(otherGivenName)
    }
    return .orderedSame
  }
}

extension Optional: Comparable where Wrapped == PersonNameComponents {
  public static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
    switch (lhs, rhs) {
    case (.none, .some):
      // No name before name
      return true
    case (.some, .none):
      return false
    case (.none, .none):
      return false
    case (.some(let lhs), .some(let rhs)):
      return lhs.compare(to: rhs) == .orderedAscending
    }
  }
}
