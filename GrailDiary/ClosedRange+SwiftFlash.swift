// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension ClosedRange where Bound == Date {
  /// The number of complete days contained in the range.
  var daysInRange: Int {
    return Calendar.current.dateComponents([.day], from: lowerBound, to: upperBound).day!
  }
}

public extension ClosedRange {
  /// Returns the combination of this range with another range.
  ///
  /// - note: It is not possible to express the combination of disjoint ranges with
  ///         a single range. In this case, the function returns nil.
  ///
  /// - parameter otherRange: The range to combine with.
  /// - returns: nil if the ranges are disjoint; otherwise, a ClosedRange that contains
  ///            all of the members of the two ranges and only those members.
  func combining(with otherRange: ClosedRange<Bound>) -> ClosedRange<Bound>? {
    guard overlaps(otherRange) else { return nil }
    let lowerBound = Swift.min(self.lowerBound, otherRange.lowerBound)
    let upperBound = Swift.max(self.upperBound, otherRange.upperBound)
    return lowerBound ... upperBound
  }
}
