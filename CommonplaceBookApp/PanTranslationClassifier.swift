// Copyright © 2017-present Brian's Brain. All rights reserved.

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
    epsilon: CGFloat = 0.3,
    triggeringMagnitude: CGFloat = 100
  ) {
    self.direction = direction
    self.epsilon = epsilon
    self.triggeringMagnitude = triggeringMagnitude
  }

  /// Direction, in radians, of the specific direction.
  public let direction: CGVector.Direction

  /// How close the pan gesture translation must be to the specified direction to match.
  public let epsilon: CGFloat

  /// How large the pan gesture translation must be to match
  public let triggeringMagnitude: CGFloat

  public func matchStrength(vector: CGVector) -> CGFloat {
    let angleDelta = abs(vector.direction.rawValue - direction.rawValue)
    let directionFactor = angleDelta
      .unitScale(zero: epsilon / 2, one: epsilon)
      .clamped(to: 0 ... 1)
      .inverted()
    let magnitudeFactor = vector.magnitude
      .unitScale(zero: triggeringMagnitude / 2, one: triggeringMagnitude)
      .clamped(to: 0 ... 1)
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
