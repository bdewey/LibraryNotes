// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
    if let due, let lastReview {
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
      // TODO: Fully support the Anki scheduler.
      // I'm trying to set the appropriate learning step here, but it's kind of pointless because
      // I don't actually persist this. Once you have a due date, you're in "review" mode.
      let learningStep = UserDefaults.standard.immediatelySchedulePrompts ? 0 : SchedulingParameters.standard.learningIntervals.count
      return PromptSchedulingMetadata(
        mode: .learning(step: learningStep),
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
