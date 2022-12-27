// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A sequence of prompts for the learner to respond to.
public struct StudySession {
  public struct SessionPromptIdentifier {
    public let noteIdentifier: Note.Identifier
    public let noteTitle: String
    public let promptIdentifier: PromptIdentifier
  }

  /// The current set of cards to study.
  private var sessionPromptIdentifiers: [SessionPromptIdentifier]

  /// The current position in `cards`
  private var currentIndex: Int

  /// Identifiers of the cards that were answered correctly the first time.
  private(set) var answeredCorrectly: Set<PromptIdentifier> = []

  /// Identifiers of cards that were answered incorrectly at least once.
  private(set) var answeredIncorrectly: Set<PromptIdentifier> = []

  /// When the person started this particular study session.
  public var studySessionStartDate: Date?

  /// When the person ended this particular study session.
  public var studySessionEndDate: Date?

  public private(set) var results = [PromptIdentifier: AnswerStatistics]()

  /// Identifiers of cards that weren't answered at all in the study session.
  var didNotAnswerAtAll: Set<PromptIdentifier> {
    var didNotAnswer = allIdentifiers
    didNotAnswer.subtract(answeredCorrectly)
    didNotAnswer.subtract(answeredIncorrectly)
    return didNotAnswer
  }

  var allIdentifiers: Set<PromptIdentifier> {
    sessionPromptIdentifiers.allIdentifiers
  }

  /// Creates a study session where all cards come from a single document.
  public init(
    _ promptIdentifiers: some Sequence<PromptIdentifier>,
    properties: CardDocumentProperties
  ) {
    let sessionPromptIdentifiers = promptIdentifiers.shuffled().map {
      SessionPromptIdentifier(noteIdentifier: properties.documentName, noteTitle: properties.attributionMarkdown, promptIdentifier: $0)
    }
    self.sessionPromptIdentifiers = sessionPromptIdentifiers
    self.currentIndex = sessionPromptIdentifiers.startIndex
  }

  /// Creates an empty study session.
  public init() {
    self.sessionPromptIdentifiers = []
    self.currentIndex = 0
  }

  public mutating func append(promptIdentifier: PromptIdentifier, properties: CardDocumentProperties) {
    let sessionPromptIdentifier = SessionPromptIdentifier(
      noteIdentifier: properties.documentName,
      noteTitle: properties.attributionMarkdown,
      promptIdentifier: promptIdentifier
    )
    sessionPromptIdentifiers.append(sessionPromptIdentifier)
  }

  /// The current card to study. Nil if we're done.
  public var currentPrompt: SessionPromptIdentifier? {
    guard currentIndex < sessionPromptIdentifiers.endIndex else { return nil }
    return sessionPromptIdentifiers[currentIndex]
  }

  /// Record a correct or incorrect answer for the current card, and advance `currentCard`
  public mutating func recordAnswer(correct: Bool) {
    guard let currentCard = currentPrompt else { return }
    let identifier = currentCard.promptIdentifier
    var statistics = results[currentCard.promptIdentifier, default: AnswerStatistics.empty]
    if correct {
      if !answeredIncorrectly.contains(identifier) { answeredCorrectly.insert(identifier) }
      statistics.correct += 1
    } else {
      answeredIncorrectly.insert(identifier)
      sessionPromptIdentifiers.append(currentCard)
      statistics.incorrect += 1
    }
    results[currentCard.promptIdentifier] = statistics
    currentIndex += 1
  }

  public mutating func limit(to promptCount: Int) {
    sessionPromptIdentifiers = Array(sessionPromptIdentifiers.prefix(promptCount))
  }

  public func limiting(to promptCount: Int) -> StudySession {
    var copy = self
    copy.limit(to: promptCount)
    return copy
  }

  /// Make sure that we don't use multiple prompts from the same prompt template.
  public mutating func ensureUniquePromptCollections() {
    var seenPromptCollections = Set<PromptIdentifier>()
    sessionPromptIdentifiers = sessionPromptIdentifiers
      .filter { sessionPromptIdentifier -> Bool in
        var identifier = sessionPromptIdentifier.promptIdentifier
        identifier.promptIndex = 0
        if seenPromptCollections.contains(identifier) {
          return false
        } else {
          seenPromptCollections.insert(identifier)
          return true
        }
      }
  }

  public func ensuringUniquePromptCollections() -> StudySession {
    var copy = self
    copy.ensureUniquePromptCollections()
    return copy
  }

  public mutating func shuffle() {
    sessionPromptIdentifiers.shuffle()
  }

  public func shuffling() -> StudySession {
    var copy = self
    copy.shuffle()
    return copy
  }

  /// Number of cards remaining in the study session.
  public var remainingPrompts: Int {
    sessionPromptIdentifiers.endIndex - currentIndex
  }

  public static func += (lhs: inout StudySession, rhs: StudySession) {
    lhs.sessionPromptIdentifiers.append(contentsOf: rhs.sessionPromptIdentifiers)
    lhs.sessionPromptIdentifiers.shuffle()
    lhs.currentIndex = 0
  }
}

extension StudySession: Collection {
  public var startIndex: Int { sessionPromptIdentifiers.startIndex }
  public var endIndex: Int { sessionPromptIdentifiers.endIndex }
  public func index(after i: Int) -> Int {
    sessionPromptIdentifiers.index(after: i)
  }

  public subscript(position: Int) -> SessionPromptIdentifier {
    sessionPromptIdentifiers[position]
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
    guard let startDate = studySessionStartDate,
          let endDate = studySessionEndDate
    else { return nil }
    return Statistics(
      startDate: startDate,
      duration: endDate.timeIntervalSince(startDate),
      answeredCorrectly: answeredCorrectly.count,
      answeredIncorrectly: answeredIncorrectly.count
    )
  }
}

extension Sequence<StudySession.SessionPromptIdentifier> {
  /// For a sequence of cards, return the set of all identifiers.
  var allIdentifiers: Set<PromptIdentifier> {
    reduce(into: Set<PromptIdentifier>()) { $0.insert($1.promptIdentifier) }
  }
}
