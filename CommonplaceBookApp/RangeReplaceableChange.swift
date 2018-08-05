// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Wraps the parameters needed to mutate a RangeReplaceableCollection.
public struct RangeReplaceableChange<Index: Comparable, ElementCollection>
  where ElementCollection: Collection {
  
  /// The range to replace
  public let range: Range<Index>
  
  /// The new elements to insert at `range`
  public let newElements: ElementCollection
  
  public init(range: Range<Index>, newElements: ElementCollection) {
    self.range = range
    self.newElements = newElements
  }
}

extension RangeReplaceableCollection {
  
  /// Changes the collection.
  ///
  /// - parameter change: The change to make.
  public mutating func applyChange<C>(
    _ change: RangeReplaceableChange<Index, C>
  ) where C.Element == Self.Element {
    replaceSubrange(change.range, with: change.newElements)
  }
  
  /// Computes how to undo a change.
  ///
  /// - parameter change: The change to make.
  /// - returns: A change that will undo `change`
  public func inverse<C>(
    of change: RangeReplaceableChange<Index, C>
  ) -> RangeReplaceableChange<Index, SubSequence> {
    let existingElements = self[change.range]
    let upperBound = index(change.range.lowerBound, offsetBy: change.newElements.count)
    return RangeReplaceableChange(
      range: change.range.lowerBound ..< upperBound,
      newElements: existingElements
    )
  }
}

