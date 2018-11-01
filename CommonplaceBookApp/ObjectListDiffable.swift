// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import IGListKit

/// This is a generic implementation of the ListDiffable protocol that wraps any NSObject.
/// The object itself is the diff identifier, and the standard isEqual: method is the implementation
/// of the ListDiffable equality check.
public final class ObjectListDiffable<Object: NSObject>: ListDiffable {
  public let value: Object

  public init(_ value: Object) {
    self.value = value
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return value
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let other = object as? ObjectListDiffable else { return false }
    return value.isEqual(other.value)
  }
}

