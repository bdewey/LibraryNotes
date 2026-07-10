// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import AppIntents
import LibraryNotesCore
import LibraryNotesUI
import os
import SwiftUI
import WidgetKit

private extension Logger {
  static let quoteWidget = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuoteOfTheDayWidget", category: "QuoteOfTheDayWidget")
}

private let quoteWidgetKind = "QuoteOfTheDayWidget"

enum QuoteWidgetRefreshSchedule: String, AppEnum {
  case daily
  case hourly

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Refresh schedule")

  static let caseDisplayRepresentations: [QuoteWidgetRefreshSchedule: DisplayRepresentation] = [
    .daily: DisplayRepresentation(title: "Daily"),
    .hourly: DisplayRepresentation(title: "Hourly"),
  ]

  var rotationSchedule: QuoteWidgetRotationSchedule {
    QuoteWidgetRotationSchedule(rawValue: rawValue) ?? .daily
  }
}

struct QuoteWidgetConfigurationIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Quote Widget"
  static let description = IntentDescription("Choose how often this widget automatically shows a new quote.")

  @Parameter(title: "Refresh schedule", default: .daily)
  var refreshSchedule: QuoteWidgetRefreshSchedule

  @Parameter(title: "Widget identifier", default: "")
  var widgetIdentifier: String

  init() {
    self.widgetIdentifier = UUID().uuidString
  }

  static var parameterSummary: some ParameterSummary {
    Summary("Refresh \(\.$refreshSchedule)")
  }
}

struct NewQuoteIntent: AppIntent {
  static let title: LocalizedStringResource = "New Quote"
  static let description = IntentDescription("Show another quote from the current widget interval.")
  static let openAppWhenRun = false

  @Parameter(title: "Refresh schedule")
  var refreshSchedule: QuoteWidgetRefreshSchedule

  @Parameter(title: "Widget identifier")
  var widgetIdentifier: String

  init() {}

  init(refreshSchedule: QuoteWidgetRefreshSchedule, widgetIdentifier: String) {
    self.refreshSchedule = refreshSchedule
    self.widgetIdentifier = widgetIdentifier
  }

  func perform() async throws -> some IntentResult {
    let store = QuoteWidgetStore()
    _ = try store.advanceManualSelection(
      widgetIdentifier: widgetIdentifier,
      schedule: refreshSchedule.rotationSchedule,
      date: .now
    )
    WidgetCenter.shared.reloadTimelines(ofKind: quoteWidgetKind)
    return .result()
  }
}

struct QuoteOfTheDayEntry: TimelineEntry {
  let date: Date
  let state: QuoteOfTheDayEntryState
  let quote: QuoteDisplayModel
  let refreshSchedule: QuoteWidgetRefreshSchedule
  let widgetIdentifier: String
  let canRequestNewQuote: Bool
}

enum QuoteOfTheDayEntryState: Sendable {
  case placeholder
  case snapshot
  case timeline
}

struct QuoteOfTheDayProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> QuoteOfTheDayEntry {
    Self.placeholderEntry(date: .now)
  }

  func snapshot(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> QuoteOfTheDayEntry {
    Self.snapshotEntry(
      date: .now,
      refreshSchedule: configuration.refreshSchedule,
      widgetIdentifier: configuration.widgetIdentifier
    )
  }

  func timeline(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> Timeline<QuoteOfTheDayEntry> {
    let now = Date()
    let entries = Self.timelineEntries(
      startingAt: now,
      refreshSchedule: configuration.refreshSchedule,
      widgetIdentifier: configuration.widgetIdentifier
    )
    return Timeline(entries: entries, policy: .atEnd)
  }

  static func placeholderEntry(date: Date) -> QuoteOfTheDayEntry {
    QuoteOfTheDayEntry(
      date: date,
      state: .placeholder,
      quote: QuoteDisplayModel(
        noteId: "placeholder",
        key: "placeholder",
        quoteText: "A favorite passage from your Dogeared library will appear here.",
        attributionText: "Quote of the Day"
      ),
      refreshSchedule: .daily,
      widgetIdentifier: "placeholder",
      canRequestNewQuote: false
    )
  }

  static func snapshotEntry(
    date: Date,
    refreshSchedule: QuoteWidgetRefreshSchedule,
    widgetIdentifier: String
  ) -> QuoteOfTheDayEntry {
    entry(
      date: date,
      state: .snapshot,
      refreshSchedule: refreshSchedule,
      widgetIdentifier: widgetIdentifier,
      cache: cachedQuotePool()
    )
  }

  static func timelineEntries(
    startingAt startDate: Date,
    refreshSchedule: QuoteWidgetRefreshSchedule,
    widgetIdentifier: String
  ) -> [QuoteOfTheDayEntry] {
    let cache = cachedQuotePool()
    let schedule = refreshSchedule.rotationSchedule
    let calendar = Calendar.current
    var dates = [startDate]
    var nextDate = schedule.nextRefreshDate(after: startDate, calendar: calendar)
    for _ in 0 ..< timelineEntryCount(for: schedule) {
      dates.append(nextDate)
      nextDate = schedule.nextRefreshDate(after: nextDate, calendar: calendar)
    }
    return dates.map { date in
      entry(
        date: date,
        state: .timeline,
        refreshSchedule: refreshSchedule,
        widgetIdentifier: widgetIdentifier,
        cache: cache
      )
    }
  }

  static func timelineEntry(
    date: Date,
    key: String,
    quoteText: String,
    attributionText: String
  ) -> QuoteOfTheDayEntry {
    QuoteOfTheDayEntry(
      date: date,
      state: .timeline,
      quote: QuoteDisplayModel(
        noteId: "timeline-\(key)",
        key: key,
        quoteText: quoteText,
        attributionText: attributionText
      ),
      refreshSchedule: .daily,
      widgetIdentifier: "preview",
      canRequestNewQuote: true
    )
  }

  private struct CachedQuotePool {
    var candidates: [QuoteWidgetCandidate]
    var errorDescription: String?
  }

  private static func entry(
    date: Date,
    state: QuoteOfTheDayEntryState,
    refreshSchedule: QuoteWidgetRefreshSchedule,
    widgetIdentifier: String,
    cache: CachedQuotePool
  ) -> QuoteOfTheDayEntry {
    let schedule = refreshSchedule.rotationSchedule
    let manualAdvanceCount: Int
    do {
      manualAdvanceCount = try QuoteWidgetStore().manualAdvanceCount(
        widgetIdentifier: widgetIdentifier,
        schedule: schedule,
        date: date
      )
    } catch {
      manualAdvanceCount = 0
      Logger.quoteWidget.error("Could not read quote widget selection state: \(error.localizedDescription, privacy: .public)")
    }
    let quote = QuoteWidgetSelection.selectedCandidate(
      from: cache.candidates,
      schedule: schedule,
      date: date,
      manualAdvanceCount: manualAdvanceCount
    ).map(QuoteDisplayModel.init) ?? diagnosticQuote(key: state.key, errorDescription: cache.errorDescription)
    return QuoteOfTheDayEntry(
      date: date,
      state: state,
      quote: quote,
      refreshSchedule: refreshSchedule,
      widgetIdentifier: widgetIdentifier,
      canRequestNewQuote: cache.candidates.count > 1
    )
  }

  private static func timelineEntryCount(for schedule: QuoteWidgetRotationSchedule) -> Int {
    switch schedule {
    case .daily:
      7
    case .hourly:
      24
    }
  }

  private static func cachedQuotePool(store: QuoteWidgetStore = QuoteWidgetStore()) -> CachedQuotePool {
    do {
      let candidates = try store.readCandidates()
      Logger.quoteWidget.info(
        "Read quote widget database: candidates=\(candidates.count), covers=\(candidates.count { $0.thumbnailImage != nil })"
      )
      return CachedQuotePool(candidates: candidates, errorDescription: nil)
    } catch {
      let errorDescription = error.localizedDescription
      Logger.quoteWidget.error("Could not read quote widget database: \(errorDescription, privacy: .public)")
      return CachedQuotePool(candidates: [], errorDescription: errorDescription)
    }
  }

  private static func diagnosticQuote(key: String, errorDescription: String?) -> QuoteDisplayModel {
    QuoteDisplayModel(
      noteId: "diagnostic",
      key: key,
      quoteText: "Widget cache unavailable.",
      attributionText: errorDescription ?? "No cached quote data was loaded."
    )
  }
}

private extension QuoteOfTheDayEntryState {
  var key: String {
    switch self {
    case .placeholder:
      "placeholder"
    case .snapshot:
      "snapshot"
    case .timeline:
      "timeline"
    }
  }
}

struct QuoteOfTheDayWidgetView: View {
  let entry: QuoteOfTheDayEntry

  @Environment(\.widgetFamily) private var widgetFamily

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      QuoteCardView(model: entry.quote, mode: displayMode)
        .padding(12)
        .padding(.bottom, entry.canRequestNewQuote ? 24 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      if entry.canRequestNewQuote {
        Button(intent: NewQuoteIntent(
          refreshSchedule: entry.refreshSchedule,
          widgetIdentifier: entry.widgetIdentifier
        )) {
          Image(systemName: "arrow.clockwise")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel("New quote")
      }
    }
    .containerBackground(Color.grailBackground, for: .widget)
    .redacted(reason: entry.state == .placeholder ? .placeholder : [])
  }

  private var displayMode: QuoteCardDisplayMode {
    switch widgetFamily {
    case .systemMedium:
      .widgetMedium
    default:
      .widgetSmall
    }
  }
}

@main
struct QuoteOfTheDayWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: quoteWidgetKind, intent: QuoteWidgetConfigurationIntent.self, provider: QuoteOfTheDayProvider()) { entry in
      QuoteOfTheDayWidgetView(entry: entry)
    }
    .configurationDisplayName("Quote of the Day")
    .description("Shows a favorite Dogeared quote. Choose daily or hourly refresh.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

#Preview(as: .systemSmall) {
  QuoteOfTheDayWidget()
} timeline: {
  QuoteOfTheDayProvider.placeholderEntry(date: .now)
  QuoteOfTheDayProvider.snapshotEntry(date: .now, refreshSchedule: .daily, widgetIdentifier: "preview")
  QuoteOfTheDayProvider.timelineEntry(
    date: .now,
    key: "preview-timeline",
    quoteText: "The road goes ever on and on",
    attributionText: "J.R.R. Tolkien, The Lord of the Rings"
  )
}
