// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

/// Contains a summary of the review history of an item, and can compute the next time
/// an item should be reviewed.
public struct StudyMetadata: Equatable, Codable {
  /// The day of a particular review.
  public let day: DayComponents

  /// The number of days from the *prior* review.
  public let daysSinceLastReview: Int?

  /// The total correct/incorrect answer history for this item.
  public let totalAnswers: AnswerStatistics

  /// The correct/incorrect answers for this item in *this* review.
  public let lastAnswers: AnswerStatistics

  /// Full initializer.
  public init(
    day: DayComponents,
    daysSinceLastReview: Int?,
    totalAnswers: AnswerStatistics,
    lastAnswers: AnswerStatistics
  ) {
    self.day = day
    self.daysSinceLastReview = daysSinceLastReview
    self.totalAnswers = totalAnswers
    self.lastAnswers = lastAnswers
  }

  /// Initialize when there is no prior history to chain to.
  ///
  /// - parameter day: The day of a specific review.
  /// - parameter lastAnswers: Answers given on this day.
  /// - note: Since there is no prior history, `totalAnswers` will be equal to `lastAnswers`
  public init(day: DayComponents, lastAnswers: AnswerStatistics) {
    self.day = day
    self.lastAnswers = lastAnswers
    self.totalAnswers = lastAnswers
    self.daysSinceLastReview = nil
  }

  /// Creates a new `StudyMetadata` structure that reflects the results of review on a day.
  ///
  /// - parameter answers: The correct/incorrect statistics for the most recent review.
  /// - parameter day: The day of the most recent review.
  /// - returns: A new `StudyMetadata` structure incorporating `answers`
  public func updatedMetadata(with answers: AnswerStatistics, on day: DayComponents) -> StudyMetadata {
    return StudyMetadata(
      day: day,
      daysSinceLastReview: day - self.day,
      totalAnswers: answers + totalAnswers,
      lastAnswers: answers
    )
  }

  /// Returns the number of days until the next review.
  ///
  /// The number of days until next review is a function of:
  ///
  /// - How many days since the *last* review
  /// - The number of correct and incorrect responses in *this* review
  ///
  /// The rough rules are, in priority order:
  ///
  /// - If you didn't have any correct responses, then you should keep reviewing
  ///   this item (daysUntilNextReview == 0)
  /// - If you had no incorrect answers, then we should wait *longer* before reviewing
  ///   the item again. The current implementation doubles `daysSinceLastReview`.
  /// - If you had exactly 1 incorrect answer, wait the *same* time before reviewing the item
  ///   again.
  /// - If you had more than 1 incorrect answer, wait *less* time before reviewing again.
  public var daysUntilNextReview: Int {
    if lastAnswers.correct == 0 { return 0 }
    guard let daysSinceLastReview = daysSinceLastReview else { return 1 }
    let factor = pow(2.0, 1.0 - Double(lastAnswers.incorrect))
    return Int(max(1, round(Double(daysSinceLastReview) * factor)))
  }

  /// Invariant: If a review results in this distribution of correct and incorrect answers,
  /// then daysUntilNextReview should equal daysSinceLastReview.
  public static let answerStatisticsForSameReviewDuration = AnswerStatistics(correct: 1, incorrect: 1)

  /// Returns true if this item is eligible for study on a particular day.
  public func eligibleForStudy(on day: DayComponents) -> Bool {
    return (day - self.day) >= daysUntilNextReview
  }

  public var dayForNextReview: DayComponents {
    return day + daysUntilNextReview
  }
}
