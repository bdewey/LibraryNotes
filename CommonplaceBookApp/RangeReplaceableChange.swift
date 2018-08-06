// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Wraps the parameters needed to mutate a RangeReplaceableCollection.
public struct RangeReplaceableChange<Index: Comparable, ElementCollection>
  where ElementCollection: Collection {
  
  /// The start location for the insertion
  public var startIndex: Index
  
  /// How many elements in the existing collection to replace
  public let countOfElementsToRemove: Int
  
  /// The new elements to insert at `startLocation`
  public let newElements: ElementCollection

  public init(startIndex: Index, countOfElementsToRemove: Int, newElements: ElementCollection) {
    self.startIndex = startIndex
    self.countOfElementsToRemove = countOfElementsToRemove
    self.newElements = newElements
  }
  
  public var delta: Int {
    return newElements.count - countOfElementsToRemove
  }
}

extension RangeReplaceableCollection {
  
  public typealias Change = RangeReplaceableChange<Index, SubSequence>
  
  /// Changes the collection.
  ///
  /// - parameter change: The change to make.
  /// - returns: A change that will undo this change.
  @discardableResult
  public mutating func applyChange<C>(
    _ change: RangeReplaceableChange<Index, C>
  ) -> Change where C.Element == Self.Element {
    let endIndex = index(change.startIndex, offsetBy: change.countOfElementsToRemove)
    let range = change.startIndex ..< endIndex
    let existingElements = self[range]
    replaceSubrange(range, with: change.newElements)
    return RangeReplaceableChange(
      startIndex: change.startIndex,
      countOfElementsToRemove: change.newElements.count,
      newElements: existingElements
    )
  }

  @discardableResult
  public mutating func applyChanges<ChangeCollection: Collection>(
    _ changes: ChangeCollection
  ) -> [Change] where ChangeCollection.Element == Change {
    var cumulativeDelta = 0
    let originalCollection = self
    let inverseChanges = changes
      .sorted(by: { $0.startIndex < $1.startIndex })
      .reversed()
      .map({ (change) -> Change in
        self.applyChange(change)
      })
      .reversed()
      .map({ (change) -> Change in
        var change = change
        change.startIndex = originalCollection.index(change.startIndex, offsetBy: cumulativeDelta)
        cumulativeDelta -= change.delta
        return change
      })
    return inverseChanges
  }
}

