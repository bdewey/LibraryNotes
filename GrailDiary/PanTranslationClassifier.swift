// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit

/// The job of a PanTranslationClassifier is to determine determine if the `translation` of a UIPanGestureRecognizer
/// matches a specific pattern. Matching is not "binary" (match / not match), but is instead expressed in a range of 0 ... 1
/// where 0 is a definite not match and a 1 is a definite match.
public protocol PanTranslationClassifier {
  /// The direction this classifier is looking for
  var direction: CGVector.Direction { get }
  /// - returns: A value in the range 0.0 ... 1.0 representing how well this pan gesture translation matches this classifier.
  func matchStrength(vector: CGVector) -> CGFloat
}

/// This classifier tries to be much simplier than LinearPanTranslation.
/// To trigger:
/// - the swipe has to be "more" in the intended direction than any other direction
/// - the swipe length needs to be at least the triggering distance.
public struct SimpleSwipeClassifier: PanTranslationClassifier {
  /// The direction this classifier is looking for
  public let direction: CGVector.Direction

  /// The minimum distance for triggering this classifier
  public let triggeringMagnitude: CGFloat = 150

  public func matchStrength(vector: CGVector) -> CGFloat {
    if vector.isInDirection(direction) {
      return (vector.magnitude / triggeringMagnitude).clamped(to: 0...1)
    } else {
      return 0
    }
  }
}

private extension CGVector {
  func isInDirection(_ direction: CGVector.Direction) -> Bool {
    switch direction {
    case .up:
      return dy < 0 && abs(dy) > abs(dx)
    case .down:
      return dy > 0 && abs(dy) > abs(dx)

    // HACK: I know I never look for the direction "up", so don't worry about negative "dy" which would indicate
    // "this swipe is more up than left/right"
    case .left:
      return dx < 0 && abs(dx) > dy
    case .right:
      return dx > 0 && abs(dx) > dy
    default:
      assertionFailure()
      return false
    }
  }
}

private extension CGFloat {
  func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    if self < range.lowerBound {
      return range.lowerBound
    }
    if self > range.upperBound {
      return range.upperBound
    }
    return self
  }
}
