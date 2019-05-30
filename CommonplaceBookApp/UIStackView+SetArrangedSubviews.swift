// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

extension UIStackView {
  /// Changes the entire set of arranged subviews, animating the transition if requested.
  ///
  /// At the end of this method, any UIView that was in the old `arrangedSubviews` but not in
  /// the new `arrangedSubviews` will still be in the view hierarchy, but its location will not
  /// be managed by the stack view and it will be invisible (alpha 0.0).
  ///
  /// - parameter newArrangedSubviews: The new set of arranged subviews.
  /// - parameter animated: If true, then the stack view animates the transition to the new state.
  public func setArrangedSubviews(_ newArrangedSubviews: [UIView], animated: Bool) {
    var finalAlpha: [UIView: CGFloat] = [:]
    for arrangedSubview in arrangedSubviews {
      finalAlpha[arrangedSubview] = 0.0
      removeArrangedSubview(arrangedSubview)
    }
    for (index, newSubview) in newArrangedSubviews.enumerated() {
      finalAlpha[newSubview] = 1.0
      insertArrangedSubview(newSubview, at: index)
    }
    let animations = {
      for (view, alpha) in finalAlpha {
        view.alpha = alpha
      }
      self.setNeedsLayout()
      self.layoutIfNeeded()
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: animations)
    } else {
      animations()
    }
  }
}
