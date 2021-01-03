//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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
