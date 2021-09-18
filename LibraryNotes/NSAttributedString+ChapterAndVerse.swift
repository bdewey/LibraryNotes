// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// "Chapter and verse" text is a parenthetical note at the end of a quote that identifies where,
/// in the source, the quote comes from.
public extension NSAttributedString {
  /// The range of a "chapter and verse" annotation inside the receiver.
  internal var rangeOfChapterAndVerseAnnotation: NSRange? {
    guard let chapterAndVerseRegularExpression = try? NSRegularExpression(
      pattern: #"\s+\([^\)]*\)\W*$"#,
      options: []
    ) else {
      assertionFailure()
      return nil
    }
    return chapterAndVerseRegularExpression.firstMatch(
      in: string,
      options: [],
      range: NSRange(location: 0, length: string.count)
    )?.range
  }

  /// The chapter and verse annotation in the receiver, if present.
  var chapterAndVerseAnnotation: Substring? {
    if
      let range = rangeOfChapterAndVerseAnnotation,
      let stringRange = Range(range, in: string)
    {
      return string[stringRange]
    } else {
      return nil
    }
  }

  /// Returns a copy of the receiver with the chapter and verse annotation removed.
  func removingChapterAndVerseAnnotation() -> NSAttributedString {
    guard let range = rangeOfChapterAndVerseAnnotation else { return self }
    // swiftlint:disable:next force_cast
    let result = mutableCopy() as! NSMutableAttributedString
    result.deleteCharacters(in: range)
    return result
  }

  /// Returns the receiver with any chapter and verse annotation, if present, removed and
  /// returned as a separate string.
  var decomposedChapterAndVerseAnnotation: (NSAttributedString, String) {
    guard let range = self.rangeOfChapterAndVerseAnnotation,
          let stringRange = Range(range, in: self.string)
    else { return (self, "") }
    let chapterAndVerse = String(string[stringRange])
    // swiftlint:disable:next force_cast
    let result = mutableCopy() as! NSMutableAttributedString
    result.deleteCharacters(in: range)
    return (result, chapterAndVerse)
  }

  func trimmingTrailingWhitespace() -> NSAttributedString {
    let rangeToTrim = string.reversed().prefix(while: { $0.isWhitespaceOrNewline })
    if rangeToTrim.isEmpty {
      return self
    }
    guard
      let index = string.index(string.endIndex, offsetBy: -1 * rangeToTrim.count, limitedBy: string.startIndex)
    else {
      return self
    }
    let nsRange = NSRange(index ..< string.endIndex, in: string)
    // swiftlint:disable:next force_cast
    let mutableCopy = self.mutableCopy() as! NSMutableAttributedString
    mutableCopy.deleteCharacters(in: nsRange)
    return mutableCopy
  }
}
