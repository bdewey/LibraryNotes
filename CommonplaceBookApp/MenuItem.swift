// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import IGListKit

public final class MenuItem: NSObject {
  public typealias DidSelectBlock = () -> Void

  public init(label: NSAttributedString, didSelect: DidSelectBlock? = nil) {
    self.label = label
    self.didSelect = didSelect
  }

  public let label: NSAttributedString
  public let didSelect: DidSelectBlock?
}

extension MenuItem: ListDiffable {
  public func diffIdentifier() -> NSObjectProtocol {
    return label
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherItem = object as? MenuItem else { return false }
    return label.isEqual(to: otherItem.label)
  }
}
