// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension NSCharacterSet {
  func contains(_ utf16: unichar?, includesNil: Bool) -> Bool {
    utf16.map(characterIsMember) ?? includesNil
  }
}
