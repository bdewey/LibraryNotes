//
//  CGFloat+Extensions.swift
//  CGFloat+Extensions
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import UIKit

public extension CGFloat {
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}
