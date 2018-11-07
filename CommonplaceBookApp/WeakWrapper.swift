// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Wraps an object and maintains a weak reference, suitable for creating weak collections.
public struct WeakWrapper<T: AnyObject> {
  public init(_ value: T) { self.value = value }
  public weak var value: T?
}
