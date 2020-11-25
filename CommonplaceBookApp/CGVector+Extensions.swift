//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import UIKit

public extension CGVector {
  /// The direction of a vector, in radians.
  struct Direction: RawRepresentable, Hashable {
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
