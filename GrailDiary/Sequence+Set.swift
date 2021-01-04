// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Allows for more fluent conversion of things to sets.
public extension Sequence where Element: Hashable {
  /// Converts the receiver into a set.
  func asSet() -> Set<Element> { Set(self) }
}
