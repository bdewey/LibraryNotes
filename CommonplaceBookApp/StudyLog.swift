//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import Logging

public struct StudyLog {
  public init() {}

  public struct Entry: Hashable, Comparable {
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

  /// Computes dates until which we should suppress the given challenge identifier from further
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

extension StudyLog: BidirectionalCollection {
  public var startIndex: Int { return entries.startIndex }
  public var endIndex: Int { return entries.endIndex }
  public func index(after i: Int) -> Int { return i + 1 }
  public func index(before i: Int) -> Int { return i - 1 }

  public subscript(position: Int) -> Entry {
    return entries[position]
  }
}
