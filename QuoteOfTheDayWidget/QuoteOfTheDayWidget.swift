// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import LibraryNotesUI
import os
import SwiftUI
import WidgetKit

private extension Logger {
  static let quoteWidget = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuoteOfTheDayWidget", category: "QuoteOfTheDayWidget")
}

struct QuoteOfTheDayEntry: TimelineEntry {
  let date: Date
  let state: QuoteOfTheDayEntryState
  let quote: QuoteDisplayModel
}

enum QuoteOfTheDayEntryState: Sendable {
  case placeholder
  case snapshot
  case timeline
}

struct QuoteOfTheDayProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuoteOfTheDayEntry {
    Self.placeholderEntry(date: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (QuoteOfTheDayEntry) -> Void) {
    completion(Self.snapshotEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteOfTheDayEntry>) -> Void) {
    let now = Date()
    let entries = Self.timelineEntries(startingAt: now)
    completion(Timeline(entries: entries, policy: .atEnd))
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
      )
    )
  }

  static func snapshotEntry(date: Date) -> QuoteOfTheDayEntry {
    let cache = cachedCandidates(limit: 1)
    let quote = if let candidate = cache.candidates.first {
      QuoteDisplayModel(candidate)
    } else {
      diagnosticQuote(key: "snapshot", errorDescription: cache.errorDescription)
    }
    return QuoteOfTheDayEntry(date: date, state: .snapshot, quote: quote)
  }

  static func timelineEntries(startingAt startDate: Date) -> [QuoteOfTheDayEntry] {
    let calendar = Calendar.current
    let cache = cachedCandidates(limit: 3)
    let candidates = cache.candidates
    if !candidates.isEmpty {
      Logger.quoteWidget.info(
        "Building quote widget timeline: candidates=\(candidates.count), covers=\(candidates.count { $0.thumbnailImage != nil }), firstCoverBytes=\(candidates.first?.thumbnailImage?.count ?? 0)"
      )
      return candidates.enumerated().map { offset, candidate in
        QuoteOfTheDayEntry(
          date: calendar.date(byAdding: .minute, value: offset * 15, to: startDate) ?? startDate,
          state: .timeline,
          quote: QuoteDisplayModel(candidate)
        )
      }
    }

    return [
      QuoteOfTheDayEntry(
        date: startDate,
        state: .timeline,
        quote: diagnosticQuote(key: "timeline", errorDescription: cache.errorDescription)
      ),
    ]
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
      )
    )
  }

  private struct CachedCandidates {
    var candidates: [QuoteWidgetCandidate]
    var errorDescription: String?
  }

  private static func cachedCandidates(limit: Int, store: QuoteWidgetStore = QuoteWidgetStore()) -> CachedCandidates {
    do {
      let candidates = try store.readCandidates(limit: limit)
      Logger.quoteWidget.info(
        "Read quote widget database: candidates=\(candidates.count), covers=\(candidates.count { $0.thumbnailImage != nil }), firstCoverBytes=\(candidates.first?.thumbnailImage?.count ?? 0)"
      )
      return CachedCandidates(candidates: candidates, errorDescription: nil)
    } catch {
      let errorDescription = error.localizedDescription
      Logger.quoteWidget.error("Could not read quote widget database: \(errorDescription, privacy: .public)")
      return CachedCandidates(candidates: [], errorDescription: errorDescription)
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

struct QuoteOfTheDayWidgetView: View {
  let entry: QuoteOfTheDayEntry

  @Environment(\.widgetFamily) private var widgetFamily

  var body: some View {
    QuoteCardView(model: entry.quote, mode: displayMode)
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
  private let kind = "QuoteOfTheDayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuoteOfTheDayProvider()) { entry in
      QuoteOfTheDayWidgetView(entry: entry)
    }
    .configurationDisplayName("Quote of the Day")
    .description("Shows a favorite Dogeared quote.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

#Preview(as: .systemSmall) {
  QuoteOfTheDayWidget()
} timeline: {
  QuoteOfTheDayProvider.placeholderEntry(date: .now)
  QuoteOfTheDayProvider.snapshotEntry(date: .now)
  QuoteOfTheDayProvider.timelineEntry(
    date: .now,
    key: "preview-timeline",
    quoteText: "The road goes ever on and on",
    attributionText: "J.R.R. Tolkien, The Lord of the Rings"
  )
}
