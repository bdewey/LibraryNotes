// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MiniMarkdown

public struct StudySession {

  public struct CardFromDocument {
    public let card: Card
    public let documentName: String
    public let documentRules: ParsingRules

    public init(card: Card, documentName: String, documentRules: ParsingRules) {
      self.card = card
      self.documentName = documentName
      self.documentRules = documentRules
    }
  }

  /// The current set of cards to study.
  private var cards: [CardFromDocument]

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

  /// Creates a study session where all cards come from a single document.
  public init<Cards: Sequence>(
    _ cards: Cards,
    documentName: String,
    documentRules: ParsingRules
  ) where Cards.Element == Card {
    let documentCards = cards.shuffled().map {
      CardFromDocument(card: $0, documentName: documentName, documentRules: documentRules)
    }
    self.cards = documentCards
    currentIndex = self.cards.startIndex
  }

  /// Creates an empty study session.
  public init() {
    self.cards = []
    self.currentIndex = 0
  }

  /// The current card to study. Nil if we're done.
  var currentCard: CardFromDocument? {
    guard currentIndex < cards.endIndex else { return nil }
    return cards[currentIndex]
  }

  /// Record a correct or incorrect answer for the current card, and advance `currentCard`
  mutating func recordAnswer(correct: Bool) {
    guard let currentCard = currentCard else { return }
    let identifier = currentCard.card.identifier
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

  public static func += (lhs: inout StudySession, rhs: StudySession) {
    lhs.cards.append(contentsOf: rhs.cards)
    lhs.cards.shuffle()
    lhs.currentIndex = 0
  }
}

extension StudySession: Collection {
  public var startIndex: Int { return cards.startIndex }
  public var endIndex: Int { return cards.endIndex }
  public func index(after i: Int) -> Int {
    return cards.index(after: i)
  }
  public subscript(position: Int) -> CardFromDocument {
    return cards[position]
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

extension Sequence where Element == StudySession.CardFromDocument {

  /// For a sequence of cards, return the set of all identifiers.
  var allIdentifiers: Set<String> {
    return self.reduce(into: Set<String>(), { $0.insert($1.card.identifier ) })
  }
}
