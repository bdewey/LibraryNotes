// Copyright © 2018-present Brian's Brain. All rights reserved.

import Foundation

fileprivate let nonWhitespace = CharacterSet.whitespacesAndNewlines.inverted

fileprivate struct TypographyConstants {
  static let openCurlyDoubleQuote: Character = "\u{201c}"
  static let closeCurlyDoubleQuote: Character = "\u{201d}"
  static let openCurlySingleQuote: Character = "\u{2018}"
  static let closeCurlySingleQuote: Character = "\u{2019}"
  static let emDash = "—"
  static let elipses = "…"
}

extension Character {
  var isNonWhitespace: Bool? {
    if unicodeScalars.count != 1 { return nil }
    return nonWhitespace.contains(unicodeScalars.first!)
  }
}

extension String {
  private struct TypographyScanner {
    var string: String
    var index: String.Index

    init(_ string: String) {
      self.string = string
      self.index = string.startIndex
    }

    mutating func advance() {
      index = string.index(after: index)
    }

    var current: Character? {
      return string.safeCharacter(at: index)
    }

    var previous: Character? {
      if index == string.startIndex {
        return nil
      } else {
        return string[string.index(before: index)]
      }
    }

    var next: Character? {
      if index == string.endIndex {
        return nil
      } else {
        return string.safeCharacter(at: string.index(after: index))
      }
    }

    mutating func replaceCurrent(with character: Character) {
      string.replaceSubrange(index ... index, with: [character])
    }

    mutating func replaceCurrent(if match: String, with replacement: String) {
      if string.distance(from: string.startIndex, to: index) < match.count - 1 {
        return
      }
      let potentialStartIndex = string.index(index, offsetBy: -1 * (match.count - 1))
      if string[potentialStartIndex ... index] == match {
        string.replaceSubrange(potentialStartIndex ... index, with: replacement)
        index = string.index(potentialStartIndex, offsetBy: replacement.count - 1)
      }
    }
  }

  func safeCharacter(at index: String.Index) -> Character? {
    if index == endIndex {
      return nil
    } else {
      return self[index]
    }
  }

  var withTypographySubstitutions: String {
    var scanner = TypographyScanner(self)
    while let current = scanner.current {
      if current == "\"" {
        // Open quote if the next thing is non-space.
        if scanner.next?.isNonWhitespace ?? false {
          scanner.replaceCurrent(with: TypographyConstants.openCurlyDoubleQuote)
        }

        // Close quote if the previous thing is non-space.
        if scanner.previous?.isNonWhitespace ?? false {
          scanner.replaceCurrent(with: TypographyConstants.closeCurlyDoubleQuote)
        }
      }
      if current == "'" {
        if scanner.next?.isNonWhitespace ?? false {
          scanner.replaceCurrent(with: TypographyConstants.openCurlySingleQuote)
        }
        if scanner.previous?.isNonWhitespace ?? false {
          scanner.replaceCurrent(with: TypographyConstants.closeCurlySingleQuote)
        }
      }
      scanner.replaceCurrent(if: "--", with: TypographyConstants.emDash)
      scanner.replaceCurrent(if: "...", with: TypographyConstants.elipses)
      scanner.replaceCurrent(if: "….", with: TypographyConstants.elipses)
      scanner.advance()
    }
    return scanner.string
  }
}
