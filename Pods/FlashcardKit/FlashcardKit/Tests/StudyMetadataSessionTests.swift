// Copyright © 2018 Brian's Brain. All rights reserved.

// swiftlint:disable force_try

import CommonplaceBook
@testable import FlashcardKit
import TextBundleKit
import XCTest

final class StudyMetadataSessionTests: XCTestCase {

  enum Error: Swift.Error {
    case cannotLoadStudySession
  }

  let testDocumentURL = FileManager.default
    .temporaryDirectory
    .appendingPathComponent("LeitnerBoxDocumentTests.deck")
  var document: TextBundleDocument!
  let associations = [
    VocabularyAssociation(spanish: "tenedor", english: "fork"),
    VocabularyAssociation(spanish: "hombre", english: "man"),
    VocabularyAssociation(spanish: "mujer", english: "woman"),
    VocabularyAssociation(spanish: "niño", english: "boy"),
    VocabularyAssociation(spanish: "niña", english: "girl"),
    ]

  var allCards: Set<String> {
    return associations
      .map({ $0.cards })
      .joined()
      .reduce(into: Set<String>(), { (results, card) in
        results.insert(card.identifier)
      })
  }

  let today: Date = {
    var todayComponents = DateComponents()
    todayComponents.day = 19
    todayComponents.month = 3
    todayComponents.year = 2008
    return Calendar.current.date(from: todayComponents)!
  }()

  override func setUp() {
    super.setUp()
    document = TextBundleDocument(fileURL: testDocumentURL)
    let didOpen = expectation(description: "did open")
    document.save(to: testDocumentURL, for: .forCreating) { (success) in
      XCTAssert(success)
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    for association in associations {
      document.appendVocabularyAssociation(association)
    }
  }

  override func tearDown() {
    super.tearDown()
    let didClose = expectation(description: "did close")
    document.close { (_) in
      try? FileManager.default.removeItem(at: self.testDocumentURL)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  @discardableResult
  private func simulateStudy(
    expecting identifiers: Set<String>,
    answerCorrectly: Set<String> = [],
    answerIncorrectly: Set<String> = [],
    doNotAnswer: Set<String> = [],
    date: Date
  ) throws -> StudySession {

    guard let associations = document.vocabularyAssociations.value else {
      XCTFail("Expected associations")
      throw Error.cannotLoadStudySession
    }
    let identifierToStudyMetadata =
      document.documentStudyMetadata.taggedResult.value!.value ??
        IdentifierToStudyMetadata.empty
    var studySession = identifierToStudyMetadata.studySession(
      from: associations.cards,
      limit: 500,
      documentName: document.fileURL.lastPathComponent,
      parsingRules: LanguageDeck.parsingRules,
      date: date
    )
    XCTAssertEqual(identifiers, studySession.allIdentifiers)

    // You need to eventually answer things correctly or the study session will never end
    var incorrectAnswers: [String: Int] = [:]
    while let card = studySession.currentCard {
      if answerCorrectly.contains(card.card.identifier) {
        studySession.recordAnswer(correct: true)
      } else if answerIncorrectly.contains(card.card.identifier) {
        let previousIncorrectAnswers = incorrectAnswers[card.card.identifier, default: 0]
        if previousIncorrectAnswers == 5 {
          studySession.recordAnswer(correct: true)
        } else {
          studySession.recordAnswer(correct: false)
          incorrectAnswers[card.card.identifier] = previousIncorrectAnswers + 1
        }
      } else {
        // An identifier that's not in either set means "end studying early"
        break
      }
    }

    if doNotAnswer.isEmpty {
      XCTAssertEqual(answerCorrectly, studySession.answeredCorrectly)
      XCTAssertEqual(answerIncorrectly, studySession.answeredIncorrectly)
      XCTAssert(studySession.didNotAnswerAtAll.isEmpty)
    } else {
      // If we end a session early by refusing to answer, then the sets can be in arbitrarily
      // incomplete states. That limits what we can assert.
      XCTAssert(studySession.didNotAnswerAtAll.isSuperset(of: doNotAnswer))
      XCTAssert(answerCorrectly.isSuperset(of: studySession.answeredCorrectly))
      XCTAssert(answerIncorrectly.isSuperset(of: studySession.answeredIncorrectly))
    }
    document.documentStudyMetadata.update(with: studySession, on: date)
    return studySession
  }

  func testSimpleStudySession() {
    let allCards = self.allCards
    try! simulateStudy(expecting: allCards, answerCorrectly: allCards, date: today)
    // Nothing left to study today!
    try! simulateStudy(expecting: [], date: today)

    // Everything is eligible tomorrow!
    var currentDay = today.addingTimeInterval(TimeInterval.day)
    let victim = allCards.first!
    try! simulateStudy(
      expecting: allCards,
      answerCorrectly: allCards.subtracting([victim]),
      answerIncorrectly: [victim],
      date: currentDay
    )
    // Nothing left!
    try! simulateStudy(expecting: [], date: today)

    // Next day, only the poor victim should be available. The others need more time.
    currentDay = currentDay.addingTimeInterval(TimeInterval.day)
    try! simulateStudy(expecting: [victim], answerCorrectly: [victim], date: currentDay)
    try! simulateStudy(expecting: [], date: today)

    // Two more days: Everything is now available again.
    // This time we're not going to answer "victim"
    currentDay = currentDay.addingTimeInterval(TimeInterval.day * 2)
    let incompleteSession = try! simulateStudy(
      expecting: allCards,
      answerCorrectly: allCards.subtracting([victim]),
      doNotAnswer: [victim],
      date: currentDay
    )
    // Things that we didn't answer in the previous session are now eligible. For grins lets
    // get them all wrong.
    try! simulateStudy(
      expecting: incompleteSession.didNotAnswerAtAll,
      answerIncorrectly: incompleteSession.didNotAnswerAtAll,
      date: currentDay
    )
    try! simulateStudy(expecting: [], date: today)

    // Two more day: The prior wrong answers are now eligible.
    currentDay = currentDay.addingTimeInterval(TimeInterval.day)
    try! simulateStudy(
      expecting: incompleteSession.didNotAnswerAtAll,
      answerCorrectly: incompleteSession.didNotAnswerAtAll,
      date: currentDay
    )
    try! simulateStudy(expecting: [], date: today)
  }

  func testIncompleteInitialStudySession() {
    let allCards = self.allCards
    try! simulateStudy(expecting: allCards, answerCorrectly: allCards, date: today)
    var currentDay = today.addingTimeInterval(TimeInterval.day)
    let victim = allCards.first!
    let session = try! simulateStudy(
      expecting: allCards,
      answerCorrectly: allCards.subtracting([victim]),
      doNotAnswer: [victim],
      date: currentDay
    )
    // Cards that we did not get to the first time are still eligible for study today,
    // and *only* those cards.
    try! simulateStudy(
      expecting: session.didNotAnswerAtAll,
      answerCorrectly: session.didNotAnswerAtAll,
      date: currentDay
    )
    try! simulateStudy(expecting: [], date: currentDay)
    currentDay = currentDay.addingTimeInterval(2 * TimeInterval.day)
    try! simulateStudy(expecting: allCards, answerCorrectly: allCards, date: currentDay)
  }
}
