// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import UIKit

public extension CGFloat {
  @MainActor
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}
