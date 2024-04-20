// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

public extension CGVector {
  /// The direction of a vector, in radians.
  struct Direction: RawRepresentable, Hashable, Sendable {
    public let rawValue: CGFloat

    public init(rawValue: CGFloat) {
      self.rawValue = rawValue
    }

    public static let right = Direction(rawValue: 0)
    public static let down = Direction(rawValue: .pi / 2)
    public static let left = Direction(rawValue: .pi)
    public static let up = Direction(rawValue: -1 * .pi / 2) // swiftlint:disable:this identifier_name
  }

  /// Convenience initializer of a CGVector as the difference between an origin and destination point.
  init(origin: CGPoint = .zero, destination: CGPoint) {
    self.init(dx: destination.x - origin.x, dy: destination.y - origin.y)
  }

  /// The magnitude of the vector.
  var magnitude: CGFloat {
    sqrt(dx * dx + dy * dy)
  }

  /// The direction of the vector.
  var direction: Direction {
    Direction(rawValue: atan2(dy, dx))
  }
}
