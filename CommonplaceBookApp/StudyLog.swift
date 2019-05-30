// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public struct StudyLog {
  public init() {}

  public struct Entry {
    public let timestamp: Date
    public let identifier: ChallengeIdentifier
    public let statistics: AnswerStatistics

    public init(timestamp: Date, identifier: ChallengeIdentifier, statistics: AnswerStatistics) {
      assert(identifier.templateDigest != nil)
      self.timestamp = timestamp
      self.identifier = identifier
      self.statistics = statistics
    }
  }

  private var entries: [Entry] = []

  public mutating func updateStudySessionResults(
    _ studySession: StudySession,
    on date: Date = Date()
  ) {
    for (identifier, statistics) in studySession.nextGenResults {
      let entry = Entry(timestamp: date, identifier: identifier, statistics: statistics)
      entries.append(entry)
    }
  }

  /// Computes dates until which we should suppress the given challenge identifier from further
  /// study.
  public func identifierSuppressionDates() -> [ChallengeIdentifier: Date] {
    return entries.reduce(into: [ChallengeIdentifier: (currentDate: Date, nextDate: Date)]()) {
      suppressionDates, entry in
      guard entry.statistics.correct > 0 else {
        suppressionDates[entry.identifier] = nil
        return
      }
      if let currentEntry = suppressionDates[entry.identifier] {
        let delta = currentEntry.currentDate.timeIntervalSince(entry.timestamp)
        let factor = pow(2.0, 1.0 - Double(entry.statistics.incorrect))
        let nextDate = entry.timestamp.addingTimeInterval(delta * factor)
        suppressionDates[entry.identifier] = (currentDate: entry.timestamp, nextDate: nextDate)
      } else {
        suppressionDates[entry.identifier] = (currentDate: entry.timestamp, nextDate: entry.timestamp.addingTimeInterval(.day))
      }
    }.mapValues { $0.nextDate }
  }
}

extension StudyLog: BidirectionalCollection {
  public var startIndex: Int { return entries.startIndex }
  public var endIndex: Int { return entries.endIndex }
  public func index(after i: Int) -> Int { return i + 1 }
  public func index(before i: Int) -> Int { return i - 1 }

  public subscript(position: Int) -> Entry {
    return entries[position]
  }
}

extension StudyLog: LosslessStringConvertible {
  public init?(_ description: String) {
    self.entries = description.split(separator: "\n").map(String.init).compactMap(Entry.init)
  }

  public var description: String {
    return entries.map { $0.description }.joined(separator: "\n").appending("\n")
  }
}

extension StudyLog.Entry: LosslessStringConvertible {
  public init?(_ description: String) {
    let components = description.split(separator: " ")
    guard
      components.count == 7,
      let date = ISO8601DateFormatter().date(from: String(components[0])),
      let index = Int(components[2]),
      let correct = Int(components[4]),
      let incorrect = Int(components[6])
    else {
      return nil
    }
    self.timestamp = date
    self.identifier = ChallengeIdentifier(templateDigest: String(components[1]), index: index)
    self.statistics = AnswerStatistics(correct: correct, incorrect: incorrect)
  }

  public var description: String {
    return [
      ISO8601DateFormatter().string(from: timestamp),
      identifier.templateDigest,
      String(describing: identifier.index),
      "correct",
      String(statistics.correct),
      "incorrect",
      String(statistics.incorrect),
    ].compactMap { $0 }.joined(separator: " ")
  }
}
