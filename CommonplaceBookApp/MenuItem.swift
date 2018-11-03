// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import IGListKit

public final class MenuItem: NSObject {
  public init(label: NSAttributedString) {
    self.label = label
  }

  public let label: NSAttributedString
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
