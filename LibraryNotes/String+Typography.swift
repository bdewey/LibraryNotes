// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

private let nonWhitespace = CharacterSet.whitespacesAndNewlines.inverted

private enum TypographyConstants {
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

private protocol Scannable: BidirectionalCollection where Element == Character {
  mutating func replaceSubrange<C: Collection>(_ bounds: ClosedRange<Index>, with: C) where C.Element == Character
  func string(from range: ClosedRange<Index>) -> String
}

private struct TypographyScanner<S: Scannable> {
  var scannable: S
  var index: S.Index
  var replacedCharacter = false

  init(_ string: S) {
    self.scannable = string
    self.index = string.startIndex
  }

  mutating func advance() {
    index = scannable.index(after: index)
  }

  var current: Character? {
    return safeCharacter(at: index)
  }

  var previous: Character? {
    if index == scannable.startIndex {
      return nil
    } else {
      return scannable[scannable.index(before: index)]
    }
  }

  var next: Character? {
    if index == scannable.endIndex {
      return nil
    } else {
      return safeCharacter(at: scannable.index(after: index))
    }
  }

  mutating func replaceCurrent(with character: Character) {
    let currentDistance = scannable.distance(from: scannable.startIndex, to: index)
    scannable.replaceSubrange(index ... index, with: [character])
    let newIndex = scannable.index(scannable.startIndex, offsetBy: currentDistance)
    assert(newIndex == index)
    index = newIndex
    replacedCharacter = true
  }

  mutating func replaceCurrent(if match: String, with replacement: String) {
    if index >= scannable.endIndex || scannable.distance(from: scannable.startIndex, to: index) < match.count - 1 {
      return
    }
    let potentialStartIndex = scannable.index(index, offsetBy: -1 * (match.count - 1))
    if scannable.string(from: potentialStartIndex ... index) == match {
      let replacementStartDistance = scannable.distance(from: scannable.startIndex, to: potentialStartIndex)
      scannable.replaceSubrange(potentialStartIndex ... index, with: replacement)
      index = scannable.index(scannable.startIndex, offsetBy: replacementStartDistance + replacement.count - 1)
    }
  }

  private func safeCharacter(at index: S.Index) -> Character? {
    if index == scannable.endIndex {
      return nil
    } else {
      return scannable[index]
    }
  }

  mutating func makeTypographySubstitutions() {
    while let current = self.current {
      if current == "\"" {
        // Open quote if the next thing is non-space.
        if next?.isNonWhitespace ?? false {
          replaceCurrent(with: TypographyConstants.openCurlyDoubleQuote)
        }

        // Close quote if the previous thing is non-space.
        if previous?.isNonWhitespace ?? false {
          replaceCurrent(with: TypographyConstants.closeCurlyDoubleQuote)
        }
      }
      if current == "'" {
        if next?.isNonWhitespace ?? false {
          replaceCurrent(with: TypographyConstants.openCurlySingleQuote)
        }
        if previous?.isNonWhitespace ?? false {
          replaceCurrent(with: TypographyConstants.closeCurlySingleQuote)
        }
      }
      replaceCurrent(if: "--", with: TypographyConstants.emDash)
      replaceCurrent(if: "...", with: TypographyConstants.elipses)
      replaceCurrent(if: "….", with: TypographyConstants.elipses)
      advance()
    }
  }
}

extension String: Scannable {
  func string(from range: ClosedRange<String.Index>) -> String {
    return String(self[range])
  }
}

extension NSMutableAttributedString: Scannable {
  public var startIndex: String.Index {
    return string.startIndex
  }

  public var endIndex: String.Index {
    return string.endIndex
  }

  public subscript(i: String.Index) -> Character {
    return string[i]
  }

  public func index(after i: String.Index) -> String.Index {
    return string.index(after: i)
  }

  public func index(before i: String.Index) -> String.Index {
    return string.index(before: i)
  }

  func string(from range: ClosedRange<String.Index>) -> String {
    return String(string[range])
  }

  func replaceSubrange<C>(_ bounds: ClosedRange<String.Index>, with replacement: C) where C: Collection, C.Element == Character {
    let nsrange = NSRange(bounds, in: string)
    replaceCharacters(in: nsrange, with: String(replacement))
  }
}

public extension String {
  var withTypographySubstitutions: String {
    var scanner = TypographyScanner(self)
    scanner.makeTypographySubstitutions()
    return scanner.scannable
  }
}

public extension NSAttributedString {
  var withTypographySubstitutions: NSAttributedString {
    let copy = mutableCopy() as! NSMutableAttributedString // swiftlint:disable:this force_cast
    var scanner = TypographyScanner(copy)
    scanner.makeTypographySubstitutions()
    return scanner.scannable
  }
}
