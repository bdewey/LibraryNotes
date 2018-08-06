// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public protocol EditableDocument: class {
  typealias StringChange = RangeReplaceableChange<String.Index, Substring>
  func applyChange(_ change: StringChange)
  var previousError: Swift.Error? { get }
  var text: String { get }
}

extension EditableDocument {
  public func applyChange(_ postFactoChange: PostFactoStringChange) {
    let change = postFactoChange.change(from: text)
    applyChange(change)
  }
}
