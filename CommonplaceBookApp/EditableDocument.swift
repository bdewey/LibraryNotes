// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public protocol EditableDocument: class {
  typealias StringChange = RangeReplaceableChange<Substring>
  func applyChange(_ change: StringChange)
  var previousError: Swift.Error? { get }
  var text: String { get }
}
