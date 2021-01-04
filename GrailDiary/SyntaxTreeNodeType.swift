// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Opaque class representing the type of a markup node.
public final class SyntaxTreeNodeType: RawRepresentable, ExpressibleByStringLiteral, Hashable, CustomStringConvertible {
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.rawValue = value
  }

  public let rawValue: String

  public var description: String { rawValue }
}
