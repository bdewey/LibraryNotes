// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public enum Note {
  /// Identifies a note.
  public struct Identifier: Hashable, RawRepresentable {
    public let rawValue: String

    public init() {
      self.rawValue = UUID().uuidString
    }

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

extension Note.Identifier: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension Note.Identifier: CustomStringConvertible {
  public var description: String { rawValue }
}

extension Note.Identifier: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
