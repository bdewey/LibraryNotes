// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

public struct StudyLog {
  public init() {}

  public struct Entry: Hashable, Comparable {
    public var timestamp: Date
    public var identifier: ChallengeIdentifier
    public var statistics: AnswerStatistics

    public init(timestamp: Date, identifier: ChallengeIdentifier, statistics: AnswerStatistics) {
      assert(identifier.templateDigest != nil)
      self.timestamp = timestamp
      self.identifier = identifier
      self.statistics = statistics
    }

    public static func < (lhs: StudyLog.Entry, rhs: StudyLog.Entry) -> Bool {
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.identifier.templateDigest != rhs.identifier.templateDigest {
        return lhs.identifier.templateDigest! < rhs.identifier.templateDigest!
      }
      if lhs.identifier.index != rhs.identifier.index {
        return lhs.identifier.index < rhs.identifier.index
      }
      if lhs.statistics.correct != rhs.statistics.correct {
        return lhs.statistics.correct < rhs.statistics.correct
      }
      return lhs.statistics.incorrect < rhs.statistics.incorrect
    }
  }

  private var entries: [Entry] = []

  /// Adds an entry to the log.
  public mutating func append(_ entry: Entry) {
    entries.append(entry)
  }

  /// Constructs an entry from parameters and inserts it into the log.
  /// (Slightly easier to use in tests.)
  public mutating func appendEntry(
    challengeIdentifier: ChallengeIdentifier,
    correct: Int = 1,
    incorrect: Int = 0,
    timestamp: Date = Date()
  ) {
    let entry = Entry(
      timestamp: timestamp,
      identifier: challengeIdentifier,
      statistics: AnswerStatistics(correct: correct, incorrect: incorrect)
    )
    entries.append(entry)
  }

  /// Constructs log entries from all of the challenges in `studySession` and adds them to the log.
  public mutating func updateStudySessionResults(
    _ studySession: StudySession,
    on date: Date = Date()
  ) {
    for (identifier, statistics) in studySession.results {
      let entry = Entry(timestamp: date, identifier: identifier, statistics: statistics)
      entries.append(entry)
    }
  }

  /// Merges the entries from another study log into this one.
  ///
  /// - Any new entries from `other` are copied into the receiver
  /// - Any duplicate entries are ignored
  /// - The results are sorted by time
  public mutating func merge(other: StudyLog) {
    entries = Array(
      Set(entries).union(Set(other.entries))
    ).sorted()
  }

  /// Computes dates until which we should suppress the given challenge identifier from further
  /// study.
  public func identifierSuppressionDates() -> [ChallengeIdentifier: Date] {
    return entries.reduce(into: [ChallengeIdentifier: (currentDate: Date, nextDate: Date)]()) {
      suppressionDates, entry in
      // We're going to trace what happens to a specific identifier
      let shouldTrace = entry.identifier == ChallengeIdentifier(
        templateDigest: "732ab6d75b1194fbfd73265a573665c113d6f9de",
        index: 2
      )
      guard entry.statistics.correct > 0 else {
        if shouldTrace {
          DDLogDebug("StudyLog: Niling date for \(entry)")
        }
        suppressionDates[entry.identifier] = nil
        return
      }
      if let currentEntry = suppressionDates[entry.identifier] {
        // The minimum delta is 1 day
        let delta = Swift.max(entry.timestamp.timeIntervalSince(currentEntry.currentDate), TimeInterval.day)
        let factor = pow(2.0, 1.0 - Double(entry.statistics.incorrect))
        let nextDate = entry.timestamp.addingTimeInterval(delta * factor)
        if shouldTrace {
          DDLogDebug(
            "StudyLog: Updating delta = \(delta / TimeInterval.day) day(s) " +
              "factor = \(factor) nextDate = \(nextDate)"
          )
        }
        suppressionDates[entry.identifier] = (currentDate: entry.timestamp, nextDate: nextDate)
      } else {
        if shouldTrace {
          DDLogDebug("StudyLog: nextDate += 1 day")
        }
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
