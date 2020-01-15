// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

/// Allows for more fluent conversion of things to sets.
public extension Sequence where Element: Hashable {
  /// Converts the receiver into a set.
  func asSet() -> Set<Element> { Set(self) }
}
