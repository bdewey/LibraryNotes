// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging

public struct StudyLog {
  public init(entries: [Entry] = []) {
    self.entries = entries
  }

  public struct Entry: Hashable, Comparable, Codable {
    public var timestamp: Date
    public var identifier: PromptIdentifier
    public var statistics: AnswerStatistics

    public init(timestamp: Date, identifier: PromptIdentifier, statistics: AnswerStatistics) {
      self.timestamp = timestamp
      self.identifier = identifier
      self.statistics = statistics
    }

    public static func < (lhs: StudyLog.Entry, rhs: StudyLog.Entry) -> Bool {
      if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
      if lhs.identifier.promptKey != rhs.identifier.promptKey {
        return lhs.identifier.promptKey < rhs.identifier.promptKey
      }
      if lhs.identifier.promptIndex != rhs.identifier.promptIndex {
        return lhs.identifier.promptIndex < rhs.identifier.promptIndex
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
    promptIdentifier: PromptIdentifier,
    correct: Int = 1,
    incorrect: Int = 0,
    timestamp: Date = Date()
  ) {
    let entry = Entry(
      timestamp: timestamp,
      identifier: promptIdentifier,
      statistics: AnswerStatistics(correct: correct, incorrect: incorrect)
    )
    entries.append(entry)
  }

  /// Constructs log entries from all of the prompts in `studySession` and adds them to the log.
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

  /// Computes dates until which we should suppress the given identifier from further
  /// study.
  public func identifierSuppressionDates() -> [PromptIdentifier: Date] {
    return entries.reduce(into: [PromptIdentifier: (currentDate: Date, nextDate: Date)]()) { suppressionDates, entry in
      guard entry.statistics.correct > 0 else {
        suppressionDates[entry.identifier] = nil
        return
      }
      if let currentEntry = suppressionDates[entry.identifier] {
        // The minimum delta is 1 day
        let delta = Swift.max(entry.timestamp.timeIntervalSince(currentEntry.currentDate), TimeInterval.day)
        let factor = pow(2.0, 1.0 - Double(entry.statistics.incorrect))
        let nextDate = entry.timestamp.addingTimeInterval(delta * factor)
        suppressionDates[entry.identifier] = (currentDate: entry.timestamp, nextDate: nextDate)
      } else {
        suppressionDates[entry.identifier] = (currentDate: entry.timestamp, nextDate: entry.timestamp.addingTimeInterval(.day))
      }
    }.mapValues { $0.nextDate }
  }
}

extension StudyLog.Entry {
  init(_ record: StudyLogEntryRecord) {
    self.timestamp = record.timestamp
    self.identifier = PromptIdentifier(noteId: record.noteId, promptKey: record.promptKey, promptIndex: record.promptIndex)
    self.statistics = AnswerStatistics(correct: record.correct, incorrect: record.incorrect)
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
