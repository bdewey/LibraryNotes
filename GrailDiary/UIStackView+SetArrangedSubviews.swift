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

public extension UIStackView {
  /// Changes the entire set of arranged subviews, animating the transition if requested.
  ///
  /// At the end of this method, any UIView that was in the old `arrangedSubviews` but not in
  /// the new `arrangedSubviews` will still be in the view hierarchy, but its location will not
  /// be managed by the stack view and it will be invisible (alpha 0.0).
  ///
  /// - parameter newArrangedSubviews: The new set of arranged subviews.
  /// - parameter animated: If true, then the stack view animates the transition to the new state.
  func setArrangedSubviews(_ newArrangedSubviews: [UIView], animated: Bool) {
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
