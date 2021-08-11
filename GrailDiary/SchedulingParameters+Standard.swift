//
//  SchedulingParameters+Standard.swift
//  SchedulingParameters+Standard
//
//  Created by Brian Dewey on 8/11/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import SpacedRepetitionScheduler

public extension SchedulingParameters {
  static let standard = SchedulingParameters(
    learningIntervals: [.day, 4 * .day],
    goodGraduatingInterval: 7 * .day
  )
}
