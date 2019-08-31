// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension Dictionary where Key == ChallengeIdentifier, Value == StudyMetadata {
  public static let empty: [ChallengeIdentifier: StudyMetadata] = [:]

  /// Builds a study session from vocabulary associations.
  public func studySession(
    from cards: [Challenge],
    limit: Int,
    properties: CardDocumentProperties,
    date: Date = Date()
  ) -> StudySession {
    let studyCards = cards
      .filter { self.eligibleForStudy(identifier: $0.challengeIdentifier, on: date) }
      .shuffled()
      .prefix(limit)
    return StudySession(studyCards, properties: properties)
  }

  private func eligibleForStudy(identifier: ChallengeIdentifier, on date: Date) -> Bool {
    let day = DayComponents(date)
    // If we have no record of this identifier, we can study it.
    return self[identifier]?.eligibleForStudy(on: day) ?? true
  }
}
