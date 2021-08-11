// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import SpacedRepetitionScheduler

public extension SchedulingParameters {
  static let standard = SchedulingParameters(
    learningIntervals: [.day, 4 * .day],
    goodGraduatingInterval: 7 * .day
  )
}
