// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

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
    safeCharacter(at: index)
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
      nil
    } else {
      safeCharacter(at: scannable.index(after: index))
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
    while let current {
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
    String(self[range])
  }
}

public final class ScannableAttributedString: Scannable {
  private let _attributedString: NSMutableAttributedString

  public var attributedString: NSAttributedString {
    _attributedString.copy() as! NSAttributedString
  }

  public init(_ attributedString: NSAttributedString) {
    self._attributedString = attributedString.mutableCopy() as! NSMutableAttributedString
  }

  public var startIndex: String.Index {
    _attributedString.string.startIndex
  }

  public var endIndex: String.Index {
    _attributedString.string.endIndex
  }

  public subscript(i: String.Index) -> Character {
    _attributedString.string[i]
  }

  public func index(after i: String.Index) -> String.Index {
    _attributedString.string.index(after: i)
  }

  public func index(before i: String.Index) -> String.Index {
    _attributedString.string.index(before: i)
  }

  func string(from range: ClosedRange<String.Index>) -> String {
    String(_attributedString.string[range])
  }

  func replaceSubrange(_ bounds: ClosedRange<String.Index>, with replacement: some Collection<Character>) {
    let nsrange = NSRange(bounds, in: _attributedString.string)
    _attributedString.replaceCharacters(in: nsrange, with: String(replacement))
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
    var scanner = TypographyScanner(ScannableAttributedString(self))
    scanner.makeTypographySubstitutions()
    return scanner.scannable.attributedString
  }
}
