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

import Logging
import UIKit

/// The job of a PanTranslationClassifier is to determine determine if the `translation` of a UIPanGestureRecognizer
/// matches a specific pattern. Matching is not "binary" (match / not match), but is instead expressed in a range of 0 ... 1
/// where 0 is a definite not match and a 1 is a definite match.
public protocol PanTranslationClassifier {
  /// - returns: A value in the range 0.0 ... 1.0 representing how well this pan gesture translation matches this classifier.
  func matchStrength(vector: CGVector) -> CGFloat
}

/// A LinearPanTranslationClassifier determines how well a pan translation matches a direction and triggering magitude.
/// To perfectly match, the translation must be in the specified direction (+/- `epsilon`) and have magnitude at least
/// `triggeringMagnitude`.
public struct LinearPanTranslationClassifier: PanTranslationClassifier {
  public init(
    direction: CGVector.Direction,
    epsilon: CGFloat = CGFloat.pi / 4,
    triggeringMagnitude: CGFloat = 100,
    debug: Bool = false
  ) {
    self.direction = direction
    self.epsilon = epsilon
    self.triggeringMagnitude = triggeringMagnitude
    self.debug = debug
  }

  /// Direction, in radians, of the specific direction.
  public let direction: CGVector.Direction

  /// How close the pan gesture translation must be to the specified direction to match.
  public let epsilon: CGFloat

  /// How large the pan gesture translation must be to match
  public let triggeringMagnitude: CGFloat

  /// If true we log debugging about triggering the classifier
  public var debug: Bool

  public func matchStrength(vector: CGVector) -> CGFloat {
    let angleDelta = min(abs(vector.direction.rawValue - direction.rawValue), abs(vector.direction.rawValue + 2 * CGFloat.pi - direction.rawValue))
    let directionFactor = angleDelta
      .unitScale(zero: epsilon / 2, one: epsilon)
      .clamped(to: 0 ... 1)
      .inverted()
    let magnitudeFactor = vector.magnitude
      .unitScale(zero: triggeringMagnitude / 2, one: triggeringMagnitude)
      .clamped(to: 0 ... 1)
    if debug {
      Logger.shared.debug("Vector \(vector.direction) \(vector.magnitude), angleDelta = \(angleDelta), magnitudeFactor = \(magnitudeFactor) directionFactor = \(directionFactor)")
    }
    return directionFactor * magnitudeFactor
  }
}

private extension CGFloat {
  func unitScale(zero: CGFloat, one: CGFloat) -> CGFloat {
    return (self - zero) / (one - zero)
  }

  func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    if self < range.lowerBound {
      return range.lowerBound
    }
    if self > range.upperBound {
      return range.upperBound
    }
    return self
  }

  func inverted() -> CGFloat {
    return 1.0 - self
  }
}
