// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// A RangeReplaceableCollection derived from an original collection and a set of normalizing
/// changes. At any time, even after mutations, you can recover a view of the collection that has
/// the normalizing changes undone.
public struct NormalizedCollection<CollectionType: RangeReplaceableCollection> {
  
  /// A change to this particular collection.
  public typealias Change = RangeReplaceableChange<CollectionType.Index, CollectionType.SubSequence>
  
  /// The original view of the collection.
  public let originalCollection: CollectionType
  
  /// The normalizing changes applied to `originalCollection` to get the current collection.
  private let normalizingChanges: [Change]
  
  public init<C: Collection>(originalCollection: CollectionType, normalizingChanges: C) where C.Element == Change {
    self.originalCollection = originalCollection
    self.normalizingChanges = normalizingChanges.sorted(by: NormalizedCollection.orderedByLowerBound)
  }
  
  /// The collection after applying normalizing changes.
  public var normalizedCollection: CollectionType {
    var results = originalCollection
    for change in normalizingChanges.reversed() {
      results.applyChange(change)
    }
    return results
  }

  private static func orderedByLowerBound(lhs: Change, rhs: Change) -> Bool {
    return lhs.range.lowerBound < rhs.range.lowerBound
  }
}

