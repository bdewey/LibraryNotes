// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// A RangeReplaceableCollection derived from an original collection and a set of normalizing
/// changes. At any time, even after mutations, you can recover a view of the collection that has
/// the normalizing changes undone.
public struct NormalizedCollection<CollectionType: RangeReplaceableCollection> {

  /// A change to this particular collection.
  public typealias Change = RangeReplaceableChange<CollectionType.SubSequence>

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

  private func adjustInverseChanges<C: Collection>(
    _ changes: [Change],
    for change: RangeReplaceableChange<C>
  ) -> [Change] {
    let range = change.range
    let delta = change.delta
    return changes.compactMap({ (change) -> Change? in
      let inverseRange = change.range
      if range.intersection(inverseRange) != nil {
        return nil
      }
      if range.lowerBound < inverseRange.lowerBound {
        var change = change
        change.range.shift(by: delta)
        return change
      } else {
        return change
      }
    })
  }

  public mutating func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C: Collection, R: RangeExpression,
    CollectionType.Element == C.Element,
    CollectionType.Index == R.Bound {
    let change = RangeReplaceableChange(
      range: NSRange(subrange, in: self),
      newElements: newElements
    )
    inverseNormalizingChanges = adjustInverseChanges(inverseNormalizingChanges, for: change)
    normalizedCollection.replaceSubrange(subrange, with: newElements)
  }
}

extension NSRange {
  init<R: RangeExpression, CollectionType: Collection>(
    _ rangeExpression: R,
    in collection: CollectionType
  ) where R.Bound == CollectionType.Index {
    let range = rangeExpression.relative(to: collection)
    self.init(
      location: collection.distance(from: collection.startIndex, to: range.lowerBound),
      length: collection.distance(from: range.lowerBound, to: range.upperBound)
    )
  }
}

extension NormalizedCollection: CustomStringConvertible where CollectionType == String {

  public var description: String {
    let description = "Normalized text: \"\(self.normalizedCollection)\"\n" +
      "Changes:\(self.normalizedCollection.describeChanges(inverseNormalizingChanges))"
    return description
  }
}
