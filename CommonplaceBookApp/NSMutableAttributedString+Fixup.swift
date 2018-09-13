// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

extension NSAttributedString.Key {
  public static let markdownOriginalString = NSMutableAttributedString.Key(
    rawValue: "markdownOriginalString"
  )
}

extension NSMutableAttributedString {

  /// A "fixup" is a replacement made to an NSAttributedString **for rendering only**.
  /// We remember the original contents as an attribute on the string so we can undo this change
  /// later, for saving.
  public struct Fixup {

    /// The range to replace.
    let range: NSRange

    /// The replacement string.
    let newString: NSAttributedString
  }

  /// Performs the fixup on the receiver.
  public func performFixup(_ change: Fixup) {
    let range = Range(change.range, in: string)!
    let original = String(string[range])
    // swiftlint:disable:next force_cast
    let new = change.newString.mutableCopy() as! NSMutableAttributedString
    new.addAttribute(
      .markdownOriginalString,
      value: original,
      range: NSRange(location: 0, length: new.length)
    )
    replaceCharacters(in: change.range, with: new)
  }

  /// Performs a collection of fixups on the receiver.
  public func performFixups<C: Collection>(_ changes: C) where C.Element == Fixup {
    for change in changes.sorted(by: { $1.range.location < $0.range.location }) {
      performFixup(change)
    }
  }
}

extension NSAttributedString {

  /// Returns a copy of the receiver's string with all of the fixups undone.
  var stringWithoutFixups: String {
    var stringCopy = self.string
    enumerateAttribute(
      .markdownOriginalString,
      in: NSRange(location: 0, length: self.length),
      options: [.reverse]) { (originalString, range, _) in
        guard let originalString = originalString as? String else { return }
        let change = RangeReplaceableChange(range: range, newElements: originalString)
        stringCopy.applyChange(change)
    }
    return stringCopy
  }
}
