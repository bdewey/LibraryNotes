// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// The automatic interval for a quote widget instance.
public enum QuoteWidgetRotationSchedule: String, CaseIterable, Codable, Sendable {
  case daily
  case hourly

  /// A stable identifier for the interval containing the supplied date.
  public func slotIdentifier(for date: Date, calendar: Calendar = .current) -> String {
    let components: DateComponents
    switch self {
    case .daily:
      components = calendar.dateComponents([.year, .month, .day], from: date)
    case .hourly:
      components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    }
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    let hour = components.hour ?? 0
    switch self {
    case .daily:
      return String(format: "%04d-%02d-%02d", year, month, day)
    case .hourly:
      return String(format: "%04d-%02d-%02dT%02d", year, month, day, hour)
    }
  }

  /// The first automatic refresh boundary strictly after the supplied date.
  public func nextRefreshDate(after date: Date, calendar: Calendar = .current) -> Date {
    var components = DateComponents()
    components.minute = 0
    components.second = 0
    switch self {
    case .daily:
      components.hour = 0
    case .hourly:
      break
    }
    return calendar.nextDate(
      after: date,
      matching: components,
      matchingPolicy: .nextTime,
      direction: .forward
    ) ?? date.addingTimeInterval(60 * 60)
  }
}

/// Selects a stable shuffled quote for a widget interval.
///
/// The manual advance count is scoped to a widget, schedule, and interval by
/// `QuoteWidgetStore`. Advancing it walks a deterministic shuffled order, so
/// a person does not see a repeat before the available candidates are used.
public enum QuoteWidgetSelection {
  public static func selectedCandidate(
    from candidates: [QuoteWidgetCandidate],
    schedule: QuoteWidgetRotationSchedule,
    date: Date,
    manualAdvanceCount: Int,
    calendar: Calendar = .current
  ) -> QuoteWidgetCandidate? {
    let slotIdentifier = schedule.slotIdentifier(for: date, calendar: calendar)
    let orderedCandidates = shuffled(candidates, seed: "\(schedule.rawValue):\(slotIdentifier)")
    guard !orderedCandidates.isEmpty else { return nil }
    return orderedCandidates[manualAdvanceCount.quotientAndRemainder(dividingBy: orderedCandidates.count).remainder]
  }

  private static func shuffled(_ candidates: [QuoteWidgetCandidate], seed: String) -> [QuoteWidgetCandidate] {
    var shuffledCandidates = candidates.sorted { $0.id < $1.id }
    var generator = StableRandomNumberGenerator(seed: seed)
    guard shuffledCandidates.count > 1 else { return shuffledCandidates }
    for index in stride(from: shuffledCandidates.count - 1, through: 1, by: -1) {
      let swapIndex = Int(generator.next() % UInt64(index + 1))
      shuffledCandidates.swapAt(index, swapIndex)
    }
    return shuffledCandidates
  }
}

private struct StableRandomNumberGenerator {
  private var state: UInt64

  init(seed: String) {
    var value: UInt64 = 14695981039346656037
    for byte in seed.utf8 {
      value ^= UInt64(byte)
      value &*= 1099511628211
    }
    self.state = value == 0 ? 1 : value
  }

  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}
