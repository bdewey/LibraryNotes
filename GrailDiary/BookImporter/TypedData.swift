// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UniformTypeIdentifiers

/// Holds data and its associated type.
public struct TypedData {
  public init(data: Data, type: UTType) {
    self.data = data
    self.type = type
  }

  public var data: Data
  public var type: UTType
}
