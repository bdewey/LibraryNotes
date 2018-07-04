//
//  UIColor+DSL.swift
//  remember
//
//  Created by Brian Dewey on 5/15/18.
//  Copyright © 2018 Brian's Brain. All rights reserved.
//

import UIKit

extension UIColor
{
  convenience init(rgb: UInt32)
  {
    self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
              green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
              blue: CGFloat(rgb & 0xFF) / 255.0,
              alpha: 1.0)
  }
}
