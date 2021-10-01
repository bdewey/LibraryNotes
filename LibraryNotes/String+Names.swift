// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension String {
  // swiftlint:disable:next force_try
  private static let initialNameRegex = try! NSRegularExpression(pattern: #"^(\w\.\s+)*(?<lastname>\w*)$"#, options: .caseInsensitive)

  /// Assuming the receiver is a name, returns a copy of the receiver where the "family name" comes first. Useful for sorting.
  func nameLastFirst() -> String {
    let matches = String.initialNameRegex.matches(in: self, options: [], range: entireStringRange)
    if let match = matches.first, let lastNameRange = Range(match.range(withName: "lastname"), in: self) {
      return String(self[lastNameRange] + " " + self[startIndex ..< lastNameRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let components = try? PersonNameComponents(self) else { return self }
    return [components.familyName, components.givenName, components.middleName]
      .compactMap { $0 }
      .joined(separator: " ")
  }

  var entireStringRange: NSRange {
    NSRange((startIndex...).relative(to: self), in: self)
  }
}
