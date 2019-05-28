// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

/// Contains counts about the number of times a prompt was answered correctly versus incorrectly.
public struct AnswerStatistics: Codable, Equatable {
  
  /// The correct count
  public var correct: Int
  
  /// The incorrect count
  public var incorrect: Int
  
  /// Convenience instance of 0 correct, 0 incorrect answers.
  public static let empty = AnswerStatistics(correct: 0, incorrect: 0)
  
  public static func + (lhs: AnswerStatistics, rhs: AnswerStatistics) -> AnswerStatistics {
    return AnswerStatistics(
      correct: lhs.correct + rhs.correct,
      incorrect: lhs.incorrect + rhs.incorrect
    )
  }
}
