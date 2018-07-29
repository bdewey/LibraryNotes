// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

protocol EditableDocument: class {
 
  func applyChange(_ change: StringChange)
  var previousError: Swift.Error? { get }
  var text: String { get }
}
