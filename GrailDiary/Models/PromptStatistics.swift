//
//  PromptStatistics.swift
//  PromptStatistics
//
//  Created by Brian Dewey on 8/1/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import SpacedRepetitionScheduler

public struct PromptStatistics: Codable {
  public init(reviewCount: Int = 0, lapseCount: Int = 0, totalCorrect: Int = 0, totalIncorrect: Int = 0, lastReview: Date? = nil, idealInterval: Double? = nil, due: Date? = nil, spacedRepetitionFactor: Double = 2.5) {
    self.reviewCount = reviewCount
    self.lapseCount = lapseCount
    self.totalCorrect = totalCorrect
    self.totalIncorrect = totalIncorrect
    self.lastReview = lastReview
    self.idealInterval = idealInterval
    self.due = due
    self.spacedRepetitionFactor = spacedRepetitionFactor
  }

  public var reviewCount: Int = 0
  public var lapseCount: Int = 0
  public var totalCorrect: Int = 0
  public var totalIncorrect: Int = 0
  public var lastReview: Date?
  public var idealInterval: Double?
  public var due: Date?
  public var spacedRepetitionFactor: Double = 2.5
}

// MARK: - Spaced repetition support

public extension PromptStatistics {
  var schedulingItem: PromptSchedulingMetadata {
    if let due = due, let lastReview = lastReview {
      let interval = due.timeIntervalSince(lastReview)
      assert(interval > 0)
      return PromptSchedulingMetadata(
        mode: .review,
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? .day,
        reviewSpacingFactor: spacedRepetitionFactor
      )
    } else {
      // Create an item that's *just about to graduate* if we've never seen it before.
      // That's because we make new items due "last learning interval" after creation
      return PromptSchedulingMetadata(
        mode: .learning(step: SchedulingParameters.standard.learningIntervals.count),
        reviewCount: reviewCount,
        lapseCount: lapseCount,
        interval: idealInterval ?? 0,
        reviewSpacingFactor: spacedRepetitionFactor
      )
    }
  }

  mutating func applySchedulingItem(_ item: PromptSchedulingMetadata, on date: Date) {
    reviewCount = item.reviewCount
    lapseCount = item.lapseCount
    spacedRepetitionFactor = item.reviewSpacingFactor
    lastReview = date
    idealInterval = item.interval
    due = date.addingTimeInterval(item.interval.fuzzed())
  }
}

extension PromptStatistics {
  internal init(_ promptRecord: PromptRecord) {
    self.reviewCount = promptRecord.reviewCount
    self.lapseCount = promptRecord.lapseCount
    self.totalCorrect = promptRecord.totalCorrect
    self.totalIncorrect = promptRecord.totalIncorrect
    self.lastReview = promptRecord.lastReview
    self.idealInterval = promptRecord.idealInterval
    self.due = promptRecord.due
    self.spacedRepetitionFactor = promptRecord.spacedRepetitionFactor
  }
}
