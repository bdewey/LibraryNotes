// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension Sequence {
  /// `allSatisfy` is in the standard library. Why not `anySatisfy`?
  func anySatisfy(_ predicate: (Element) -> Bool) -> Bool {
    for element in self {
      if predicate(element) { return true }
    }
    return false
  }
}
