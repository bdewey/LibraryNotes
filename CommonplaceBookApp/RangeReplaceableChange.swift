// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Wraps the parameters needed to mutate a RangeReplaceableCollection.
public struct RangeReplaceableChange<ElementCollection>
  where ElementCollection: Collection {

  public var range: NSRange
  
  /// The new elements to insert at `startLocation`
  public let newElements: ElementCollection

  public init(range: NSRange, newElements: ElementCollection) {
    self.range = range
    self.newElements = newElements
  }
  
  public var delta: Int {
    return newElements.count - range.length
  }
}

extension NSRange {
  public func relative<C: Collection>(to collection: C) -> Range<C.Index> {
    let lowerBound = collection.index(collection.startIndex, offsetBy: location)
    let upperBound = collection.index(lowerBound, offsetBy: length)
    return lowerBound ..< upperBound
  }

  public mutating func shift(by delta: Int) {
    location += delta
  }
}

extension RangeReplaceableCollection {
  
  public typealias Change = RangeReplaceableChange<SubSequence>
  
  /// Changes the collection.
  ///
  /// - parameter change: The change to make.
  /// - returns: A change that will undo this change.
  @discardableResult
  public mutating func applyChange<C>(
    _ change: RangeReplaceableChange<C>
  ) -> Change where C.Element == Self.Element {
    let range = change.range.relative(to: self)
    let existingElements = self[range]
    replaceSubrange(range, with: change.newElements)
    return RangeReplaceableChange(
      range: NSRange(location: change.range.location, length: change.newElements.count),
      newElements: existingElements
    )
  }

  @discardableResult
  public mutating func applyChanges<ChangeCollection: Collection>(
    _ changes: ChangeCollection
  ) -> [Change] where ChangeCollection.Element == Change {
    var cumulativeDelta = 0
    let preChangeSnapshot = self
    print("Applying changes to '\(String(describing: self).addingSpecialCharacterEscapes)'" + describeChanges(changes))
    let changesNeedingFixup = changes
      .sorted(by: { $0.range.location < $1.range.location })
      .reversed()
      .map({ (change) -> Change in
        self.applyChange(change)
      })
    print("self is now: '\(String.init(describing: self).addingSpecialCharacterEscapes)'\nInverted changes that need fixup: " + preChangeSnapshot.describeChanges(changesNeedingFixup.reversed()))
    let fixedChanges = changesNeedingFixup
      .reversed()
      .map({ (change) -> Change in
        var change = change
        change.range.shift(by: cumulativeDelta)
        cumulativeDelta -= change.delta
        return change
      })
    print("Fixed changes: " + describeChanges(fixedChanges))
    return fixedChanges
  }

  public func describeChange(_ change: Change) -> String {
    return "[\(change.range.location), \(change.range.length)] '\(String(describing: change.newElements).addingSpecialCharacterEscapes)'"
  }

  public func describeChanges<ChangeCollection: Collection>(_ changes: ChangeCollection) -> String where ChangeCollection.Element == Change {
    return "Changes: [\n" + changes.map({ "  " + self.describeChange($0) }).joined(separator: ",\n") + "\n]"
  }
}

extension String {
  var addingSpecialCharacterEscapes: String {
    return self
      .replacingOccurrences(of: "\t", with: "\\t")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
  }
}
