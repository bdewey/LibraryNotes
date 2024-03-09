// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Contains counts about the number of times a prompt was answered correctly versus incorrectly.
public struct AnswerStatistics: Codable, Equatable, Hashable {
  /// The correct count
  public var correct: Int

  /// The incorrect count
  public var incorrect: Int

  /// Convenience instance of 0 correct, 0 incorrect answers.
  @MainActor
  public static let empty = AnswerStatistics(correct: 0, incorrect: 0)

  public static func + (lhs: AnswerStatistics, rhs: AnswerStatistics) -> AnswerStatistics {
    AnswerStatistics(
      correct: lhs.correct + rhs.correct,
      incorrect: lhs.incorrect + rhs.incorrect
    )
  }
}
