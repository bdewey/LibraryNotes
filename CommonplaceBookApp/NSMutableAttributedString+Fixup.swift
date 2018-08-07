// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

extension NSAttributedString.Key {
  public static let markdownOriginalString = NSMutableAttributedString.Key(rawValue: "markdownOriginalString")
}

extension NSMutableAttributedString {
  
  public struct Fixup {
    let range: NSRange
    let newString: NSAttributedString
  }
  
  public func performFixup(_ change: Fixup) {
    let range = Range(change.range, in: string)!
    let original = String(string[range])
    let new = change.newString.mutableCopy() as! NSMutableAttributedString
    new.addAttribute(.markdownOriginalString, value: original, range: NSRange(location: 0, length: new.length))
    replaceCharacters(in: change.range, with: new)
  }
  
  public func performFixups<C: Collection>(_ changes: C) where C.Element == Fixup {
    for change in changes.sorted(by: { $1.range.location < $0.range.location }) {
      performFixup(change)
    }
  }
}

extension NSAttributedString {
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
