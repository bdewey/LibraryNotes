// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

/// Public API for working with study sessions.
public extension NoteBundle {
  /// Returns a study session given the current notebook pages and study metadata (which indicates
  /// what cards have been studied, and therefore don't need to be studied today).
  ///
  /// - parameter filter: An optional function that determines if a page should be included in
  ///                     the study session. If no filter is given, the all pages will be used
  ///                     to construct the session.
  /// - parameter date: The date of the study session, used for spaced repetition
  /// - returns: A StudySession!
  func studySession(
    filter: ((String, PageProperties) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    return pageProperties
      .filter { filter($0.key, $0.value) }
      .map { (name, reviewProperties) -> StudySession in
        let challengeTemplates = reviewProperties.cardTemplates.compactMap {
          self.challengeTemplates[$0]
        }
        let eligibleCards = challengeTemplates.cards.filter { challenge -> Bool in
          if let metadata = self.studyMetadata(for: challenge.challengeIdentifier) {
            return metadata.eligibleForStudy(on: DayComponents(date))
          } else {
            return true
          }
        }
        return StudySession(
          eligibleCards,
          properties: CardDocumentProperties(
            documentName: name,
            attributionMarkdown: reviewProperties.title,
            parsingRules: self.parsingRules
          )
        )
      }
      .reduce(into: StudySession(), { $0 += $1 })
  }

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  mutating func updateStudySessionResults(_ studySession: StudySession, on date: Date = Date()) {
    for (identifier, statistics) in studySession.nextGenResults {
      let entry = ChangeRecord(
        timestamp: date,
        change: .study(identifier: identifier, statistics: statistics)
      )
      log.append(entry)
    }
  }
}

/// Private APIs supporting study sessions.
private extension NoteBundle {
  /// Reduces the log to compute a StudyMetadata for a particular challenge.
  func studyMetadata(for challengeIdentifier: ChallengeIdentifier) -> StudyMetadata? {
    return log
      .compactMap { changeRecord -> (Date, AnswerStatistics)? in
        if case let .study(recordIdentifier, statistics) = changeRecord.change,
          recordIdentifier == challengeIdentifier {
          return (changeRecord.timestamp, statistics)
        } else {
          return nil
        }
      }
      .reduce(nil, { studyMetadata, tuple -> StudyMetadata? in
        let (timestamp, statistics) = tuple
        if let studyMetadata = studyMetadata {
          return studyMetadata.updatedMetadata(with: statistics, on: DayComponents(timestamp))
        } else {
          return StudyMetadata(day: DayComponents(timestamp), lastAnswers: statistics)
        }
      })
  }
}
