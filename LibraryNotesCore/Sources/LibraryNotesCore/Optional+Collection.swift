// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension Optional where Wrapped: Collection {
  /// Convenience: A meaningful definition on `isEmpty` on an Optional collection.
  /// Nil collections are clearly empty.
  var isEmpty: Bool {
    switch self {
    case .none:
      true
    case .some(let wrapped):
      wrapped.isEmpty
    }
  }
}
