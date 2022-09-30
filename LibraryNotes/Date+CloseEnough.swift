// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension Date {
  /// True if the receiver and `other` are "close enough"
  func withinInterval(_ timeInterval: TimeInterval, of other: Date) -> Bool {
    abs(timeIntervalSince(other)) < timeInterval
  }
}
