// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

/// A sequence of challenges for the learner to respond to.
public struct StudySession {
  public struct SessionChallengeIdentifier {
    public let noteIdentifier: Note.Identifier
    public let noteTitle: String
    public let challengeIdentifier: ChallengeIdentifier
  }

  /// The current set of cards to study.
  private var sessionChallengeIdentifiers: [SessionChallengeIdentifier]

  /// The current position in `cards`
  private var currentIndex: Int

  /// Identifiers of the cards that were answered correctly the first time.
  private(set) var answeredCorrectly: Set<ChallengeIdentifier> = []

  /// Identifiers of cards that were answered incorrectly at least once.
  private(set) var answeredIncorrectly: Set<ChallengeIdentifier> = []

  /// When the person started this particular study session.
  public var studySessionStartDate: Date?

  /// When the person ended this particular study session.
  public var studySessionEndDate: Date?

  public private(set) var results = [ChallengeIdentifier: AnswerStatistics]()

  /// Identifiers of cards that weren't answered at all in the study session.
  var didNotAnswerAtAll: Set<ChallengeIdentifier> {
    var didNotAnswer = allIdentifiers
    didNotAnswer.subtract(answeredCorrectly)
    didNotAnswer.subtract(answeredIncorrectly)
    return didNotAnswer
  }

  var allIdentifiers: Set<ChallengeIdentifier> {
    return sessionChallengeIdentifiers.allIdentifiers
  }

  /// Creates a study session where all cards come from a single document.
  public init<ChallengeIdentifiers: Sequence>(
    _ challengeIdentifiers: ChallengeIdentifiers,
    properties: CardDocumentProperties
  ) where ChallengeIdentifiers.Element == ChallengeIdentifier {
    let sessionChallengeIdentifiers = challengeIdentifiers.shuffled().map {
      SessionChallengeIdentifier(noteIdentifier: properties.documentName, noteTitle: properties.attributionMarkdown, challengeIdentifier: $0)
    }
    self.sessionChallengeIdentifiers = sessionChallengeIdentifiers
    currentIndex = self.sessionChallengeIdentifiers.startIndex
  }

  /// Creates an empty study session.
  public init() {
    self.sessionChallengeIdentifiers = []
    self.currentIndex = 0
  }

  /// The current card to study. Nil if we're done.
  public var currentCard: SessionChallengeIdentifier? {
    guard currentIndex < sessionChallengeIdentifiers.endIndex else { return nil }
    return sessionChallengeIdentifiers[currentIndex]
  }

  /// Record a correct or incorrect answer for the current card, and advance `currentCard`
  public mutating func recordAnswer(correct: Bool) {
    guard let currentCard = currentCard else { return }
    let identifier = currentCard.challengeIdentifier
    var statistics = results[currentCard.challengeIdentifier, default: AnswerStatistics.empty]
    if correct {
      if !answeredIncorrectly.contains(identifier) { answeredCorrectly.insert(identifier) }
      statistics.correct += 1
    } else {
      answeredIncorrectly.insert(identifier)
      sessionChallengeIdentifiers.append(currentCard)
      statistics.incorrect += 1
    }
    results[currentCard.challengeIdentifier] = statistics
    currentIndex += 1
  }

  public mutating func limit(to cardCount: Int) {
    sessionChallengeIdentifiers = Array(sessionChallengeIdentifiers.prefix(cardCount))
  }

  public func limiting(to cardCount: Int) -> StudySession {
    var copy = self
    copy.limit(to: cardCount)
    return copy
  }

  public mutating func ensureUniqueChallengeTemplates() {
    var seenChallengeTemplateIdentifiers = Set<FlakeID>()
    sessionChallengeIdentifiers = sessionChallengeIdentifiers
      .filter { challengeIdentifier -> Bool in
        guard let templateIdentifier = challengeIdentifier.challengeIdentifier.challengeTemplateID else {
          assertionFailure()
          return false
        }
        if seenChallengeTemplateIdentifiers.contains(templateIdentifier) {
          return false
        } else {
          seenChallengeTemplateIdentifiers.insert(templateIdentifier)
          return true
        }
      }
  }

  public func ensuringUniqueChallengeTemplates() -> StudySession {
    var copy = self
    copy.ensureUniqueChallengeTemplates()
    return copy
  }

  public mutating func shuffle() {
    sessionChallengeIdentifiers.shuffle()
  }

  public func shuffling() -> StudySession {
    var copy = self
    copy.shuffle()
    return copy
  }

  /// Number of cards remaining in the study session.
  public var remainingCards: Int {
    return sessionChallengeIdentifiers.endIndex - currentIndex
  }

  public static func += (lhs: inout StudySession, rhs: StudySession) {
    lhs.sessionChallengeIdentifiers.append(contentsOf: rhs.sessionChallengeIdentifiers)
    lhs.sessionChallengeIdentifiers.shuffle()
    lhs.currentIndex = 0
  }
}

extension StudySession: Collection {
  public var startIndex: Int { return sessionChallengeIdentifiers.startIndex }
  public var endIndex: Int { return sessionChallengeIdentifiers.endIndex }
  public func index(after i: Int) -> Int {
    return sessionChallengeIdentifiers.index(after: i)
  }

  public subscript(position: Int) -> SessionChallengeIdentifier {
    return sessionChallengeIdentifiers[position]
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
      answeredCorrectly: answeredCorrectly.count,
      answeredIncorrectly: answeredIncorrectly.count
    )
  }
}

extension Sequence where Element == StudySession.SessionChallengeIdentifier {
  /// For a sequence of cards, return the set of all identifiers.
  var allIdentifiers: Set<ChallengeIdentifier> {
    return reduce(into: Set<ChallengeIdentifier>()) { $0.insert($1.challengeIdentifier) }
  }
}
