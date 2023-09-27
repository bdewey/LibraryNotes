// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

private let useSystemColors = false

extension UIColor {
  static let grailTint = UIColor.systemOrange

  static let grailGroupedBackground = useSystemColors
    ? UIColor.systemGroupedBackground
    : UIColor(named: "grailSecondaryBackground")!
}
