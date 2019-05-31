// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

extension Optional where Wrapped: Collection {
  /// Convenience: A meaningful definition on `isEmpty` on an Optional collection.
  /// Nil collections are clearly empty.
  var isEmpty: Bool {
    switch self {
    case .none:
      return true
    case .some(let wrapped):
      return wrapped.isEmpty
    }
  }
}
