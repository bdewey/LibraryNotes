// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation

extension String {
  // swiftlint:disable:next force_try
  private static let initialNameRegex = try! NSRegularExpression(pattern: #"^(\w\.\s+)*(?<lastname>\w*)$"#, options: .caseInsensitive)
  public func nameLastFirst() -> String {
    let matches = String.initialNameRegex.matches(in: self, options: [], range: entireStringRange)
    if let match = matches.first, let lastNameRange = Range(match.range(withName: "lastname"), in: self) {
      return String(self[lastNameRange] + " " + self[startIndex ..< lastNameRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let components = try? PersonNameComponents(self) else { return self }
    return [components.familyName, components.givenName, components.middleName]
      .compactMap { $0 }
      .joined(separator: " ")
  }

  public var entireStringRange: NSRange {
    NSRange((startIndex...).relative(to: self), in: self)
  }
}
