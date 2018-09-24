// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation

extension Sequence where Element == Card {

  /// For a sequence of cards, return the set of all identifiers.
  var allIdentifiers: Set<String> {
    return self.reduce(into: Set<String>(), { $0.insert($1.identifier ) })
  }
}

public struct StudySession {

  /// The current set of cards to study.
  private var cards: [Card]

  /// The current position in `cards`
  private var currentIndex: Int

  /// Identifiers of the cards that were answered correctly the first time.
  private(set) var answeredCorrectly: Set<String> = []

  /// Identifiers of cards that were answered incorrectly at least once.
  private(set) var answeredIncorrectly: Set<String> = []

  /// When the person started this particular study session.
  public var studySessionStartDate: Date?

  /// When the person ended this particular study session.
  public var studySessionEndDate: Date?

  private(set) public var results: [String: AnswerStatistics] = [:]

  /// Identifiers of cards that weren't answered at all in the study session.
  var didNotAnswerAtAll: Set<String> {
    var didNotAnswer = allIdentifiers
    didNotAnswer.subtract(answeredCorrectly)
    didNotAnswer.subtract(answeredIncorrectly)
    return didNotAnswer
  }

  var allIdentifiers: Set<String> {
    return cards.allIdentifiers
  }

  init<Cards: Sequence>(_ cards: Cards) where Cards.Element == Card {
    self.cards = cards.shuffled()
    currentIndex = self.cards.startIndex
  }

  /// The current card to study. Nil if we're done.
  var currentCard: Card? {
    guard currentIndex < cards.endIndex else { return nil }
    return cards[currentIndex]
  }

  /// Record a correct or incorrect answer for the current card, and advance `currentCard`
  mutating func recordAnswer(correct: Bool) {
    guard let currentCard = currentCard else { return }
    let identifier = currentCard.identifier
    var statistics = results[identifier, default: AnswerStatistics.empty]
    if correct {
      if !answeredIncorrectly.contains(identifier) { answeredCorrectly.insert(identifier) }
      statistics.correct += 1
    } else {
      answeredIncorrectly.insert(identifier)
      cards.append(currentCard)
      statistics.incorrect += 1
    }
    results[identifier] = statistics
    currentIndex += 1
  }

  /// Number of cards remaining in the study session.
  var remainingCards: Int {
    return cards.endIndex - currentIndex
  }
}

extension StudySession {
  public struct Statistics: Codable {
    public let startDate: Date
    public let duration: TimeInterval
    public let answeredCorrectly: Int
    public let answeredIncorrectly: Int
  }

  var statistics: Statistics? {
    guard let startDate = self.studySessionStartDate,
          let endDate = self.studySessionEndDate
          else { return nil }
    return Statistics(
      startDate: startDate,
      duration: endDate.timeIntervalSince(startDate),
      answeredCorrectly: self.answeredCorrectly.count,
      answeredIncorrectly: self.answeredIncorrectly.count
    )
  }
}
