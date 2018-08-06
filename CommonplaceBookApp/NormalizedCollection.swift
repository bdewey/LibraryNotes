// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// A RangeReplaceableCollection derived from an original collection and a set of normalizing
/// changes. At any time, even after mutations, you can recover a view of the collection that has
/// the normalizing changes undone.
public struct NormalizedCollection<CollectionType: RangeReplaceableCollection> {
  
  /// A change to this particular collection.
  public typealias Change = RangeReplaceableChange<CollectionType.Index, CollectionType.SubSequence>
  
  public init() { }
  
  public init<ChangeCollection: Collection>(
    originalCollection: CollectionType,
    normalizingChanges: ChangeCollection
  ) where ChangeCollection.Element == Change {
    setOriginalCollection(originalCollection, normalizingChanges: normalizingChanges)
  }

  /// The collection after applying normalizing changes.
  public private(set) var normalizedCollection = CollectionType()
  
  /// Changes will recover the original collection.
  private var inverseNormalizingChanges: [Change] = []
  
  public mutating func setOriginalCollection<ChangeCollection: Collection>(
    _ originalCollection: CollectionType,
    normalizingChanges: ChangeCollection
  ) where ChangeCollection.Element == Change {
    normalizedCollection = originalCollection
    inverseNormalizingChanges = normalizedCollection.applyChanges(normalizingChanges)
  }
  
  /// The original view of the collection.
  public var originalCollection: CollectionType {
    var results = normalizedCollection
    results.applyChanges(inverseNormalizingChanges)
    return results
  }
  
  private static func orderedByLowerBound(lhs: Change, rhs: Change) -> Bool {
    return lhs.startIndex < rhs.startIndex
  }
}

extension NormalizedCollection: Collection, RangeReplaceableCollection {
  
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
  
  private func range<C>(of change: RangeReplaceableChange<CollectionType.Index, C>) -> Range<Index> {
    let endIndex = index(change.startIndex, offsetBy: change.countOfElementsToRemove)
    let range = change.startIndex ..< endIndex
    return range
  }
  
  private func adjustInverseChanges<C: Collection>(
    _ changes: [Change],
    for change: RangeReplaceableChange<CollectionType.Index, C>
  ) -> [Change] {
    let range = self.range(of: change)
    let delta = change.newElements.count - change.countOfElementsToRemove
    return changes.compactMap({ (change) -> Change? in
      let inverseRange = self.range(of: change)
      if range.overlaps(inverseRange) {
        return nil
      }
      if range.lowerBound < inverseRange.lowerBound {
        return Change(
          startIndex: index(change.startIndex, offsetBy: delta),
          countOfElementsToRemove: change.countOfElementsToRemove,
          newElements: change.newElements
        )
      } else {
        return change
      }
    })
  }
  
  public mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C) where C : Collection, R : RangeExpression, CollectionType.Element == C.Element, CollectionType.Index == R.Bound {
    let range = subrange.relative(to: self)
    let change = RangeReplaceableChange(
      startIndex: range.lowerBound,
      countOfElementsToRemove: distance(from: range.lowerBound, to: range.upperBound),
      newElements: newElements
    )
    inverseNormalizingChanges = adjustInverseChanges(inverseNormalizingChanges, for: change)
    normalizedCollection.replaceSubrange(subrange, with: newElements)
  }
}

extension NormalizedCollection: CustomStringConvertible where CollectionType == String {

  public var description: String {
    let changes = inverseNormalizingChanges.map { (change) -> String in
      let location = normalizedCollection.distance(from: normalizedCollection.startIndex, to: change.startIndex)
      let endIndex = normalizedCollection.index(change.startIndex, offsetBy: change.countOfElementsToRemove)
      let replaced = normalizedCollection[change.startIndex ..< endIndex]
      return String(format: "(%d, %d) Replace '%@' with '%@'", location, change.countOfElementsToRemove, String(replaced), String(change.newElements))
    }
    let description = "Normalized text: \"\(self.normalizedCollection)\"\nChanges:\(changes)"
    return description
  }
}
