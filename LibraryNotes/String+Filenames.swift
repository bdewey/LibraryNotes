// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension String {
  func sanitized(maximumLength: Int = 32) -> String {
    // see for ressoning on charachrer sets https://superuser.com/a/358861
    var invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
      .union(.newlines)
      .union(.illegalCharacters)
      .union(.controlCharacters)
      .union(.punctuationCharacters)

    invalidCharacters.remove("-")

    let slice = components(separatedBy: invalidCharacters)
      .joined(separator: "")
      .prefix(maximumLength)
    return String(slice)
  }

  mutating func sanitize() {
    self = sanitized()
  }

  func whitespaceCondensed() -> String {
    return components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: "-")
  }

  mutating func condenseWhitespace() {
    self = whitespaceCondensed()
  }
}
