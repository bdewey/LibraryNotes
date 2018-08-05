// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// A RangeReplaceableCollection derived from an original collection and a set of normalizing
/// changes. At any time, even after mutations, you can recover a view of the collection that has
/// the normalizing changes undone.
public struct NormalizedCollection<CollectionType: RangeReplaceableCollection> {
  
  /// A change to this particular collection.
  public typealias Change = RangeReplaceableChange<CollectionType.Index, CollectionType.SubSequence>
  
  /// The collection after applying normalizing changes.
  public var normalizedCollection: CollectionType
  
  /// Changes will recover the original collection.
  private var inverseNormalizingChanges: [Change] = []
  
  public init<C: Collection>(
    originalCollection: CollectionType,
    normalizingChanges: C
  ) where C.Element == Change {
    normalizedCollection = originalCollection
    for change in normalizingChanges.sorted(by: NormalizedCollection.orderedByLowerBound).reversed() {
      let inverse = normalizedCollection.applyChange(change)
      inverseNormalizingChanges.append(inverse)
    }
  }
  
  /// The original view of the collection.
  public var originalCollection: CollectionType {
    var results = normalizedCollection
    for change in inverseNormalizingChanges.reversed() {
      results.applyChange(change)
    }
    return results
  }
  
  private static func orderedByLowerBound(lhs: Change, rhs: Change) -> Bool {
    return lhs.range.lowerBound < rhs.range.lowerBound
  }
}

extension NormalizedCollection: Collection, RangeReplaceableCollection {

  public init() {
    self.init(originalCollection: CollectionType(), normalizingChanges: [])
  }
  
  public var startIndex: CollectionType.Index {
    return normalizedCollection.startIndex
  }
  
  public var endIndex: CollectionType.Index {
    return normalizedCollection.endIndex
  }
  
  public func index(after i: CollectionType.Index) -> CollectionType.Index {
    return normalizedCollection.index(after: i)
  }
  
  public subscript(i: CollectionType.Index) -> CollectionType.Element {
    get {
      return normalizedCollection[i]
    }
    set {
      let nextIndex = index(after: i)
      replaceSubrange(i ..< nextIndex, with: [newValue])
    }
  }
  
  private func shiftedRange(
    _ range: Range<CollectionType.Index>,
    by delta: Int
  ) -> Range<CollectionType.Index> {
    if delta == 0 { return range }
    return index(range.lowerBound, offsetBy: delta) ..< index(range.upperBound, offsetBy: delta)
  }
  
  private func adjustInverseChanges<C: Collection>(_ changes: [Change], for change: RangeReplaceableChange<CollectionType.Index, C>) -> [Change] {
    let range = change.range
    let subrangeLength = distance(from: range.lowerBound, to: range.upperBound)
    let delta = change.newElements.count - subrangeLength
    return changes.compactMap({ (change) -> Change? in
      if range.overlaps(change.range) { return nil }
      if range.lowerBound < change.range.lowerBound {
        return Change(range: shiftedRange(change.range, by: delta), newElements: change.newElements)
      } else {
        return change
      }
    })
  }
  
  public mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, CollectionType.Element == C.Element, CollectionType.Index == R.Bound {
    let range = subrange.relative(to: self)
    let change = RangeReplaceableChange(range: range, newElements: newElements)
    inverseNormalizingChanges = adjustInverseChanges(inverseNormalizingChanges, for: change)
    normalizedCollection.replaceSubrange(subrange, with: newElements)
  }
}
