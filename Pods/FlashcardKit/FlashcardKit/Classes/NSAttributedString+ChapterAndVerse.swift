// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

/// "Chapter and verse" text is a parenthetical note at the end of a quote that identifies where,
/// in the source, the quote comes from.
extension NSAttributedString {

  /// The range of a "chapter and verse" annotation inside the receiver.
  var rangeOfChapterAndVerseAnnotation: NSRange? {
    guard let chapterAndVerseRegularExpression = try? NSRegularExpression(
      pattern: "\\s+\\(\\S*\\)\\s*$",
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
  public var chapterAndVerseAnnotation: Substring? {
    if let range = self.rangeOfChapterAndVerseAnnotation,
      let stringRange = Range(range, in: self.string) {
      return self.string[stringRange]
    } else {
      return nil
    }
  }

  /// Returns a copy of the receiver with the chapter and verse annotation removed.
  public func removingChapterAndVerseAnnotation() -> NSAttributedString {
    guard let range = self.rangeOfChapterAndVerseAnnotation else { return self }
    // swiftlint:disable:next force_cast
    let result = self.mutableCopy() as! NSMutableAttributedString
    result.deleteCharacters(in: range)
    return result
  }

  /// Returns the receiver with any chapter and verse annotation, if present, removed and
  /// returned as a separate string.
  public var decomposedChapterAndVerseAnnotation: (NSAttributedString, String) {
    guard let range = self.rangeOfChapterAndVerseAnnotation,
          let stringRange = Range(range, in: self.string)
          else { return (self, "") }
    let chapterAndVerse = String(self.string[stringRange])
    // swiftlint:disable:next force_cast
    let result = self.mutableCopy() as! NSMutableAttributedString
    result.deleteCharacters(in: range)
    return (result, chapterAndVerse)
  }
}
