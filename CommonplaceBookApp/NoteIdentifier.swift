// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

/// Identifies a page inside NoteStorage.
/// From https://www.swiftbysundell.com/articles/type-safe-identifiers-in-swift/
public struct NoteIdentifier: Hashable, RawRepresentable {
  public let rawValue: String

  public init() {
    self.rawValue = UUID().uuidString
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension NoteIdentifier: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension NoteIdentifier: CustomStringConvertible {
  public var description: String { rawValue }
}

extension NoteIdentifier: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
