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
    let snapshot = cachedSnapshot()
    let quote = if let candidate = snapshot.candidates.first {
      QuoteDisplayModel(candidate)
    } else {
      diagnosticQuote(key: "snapshot", errorDescription: snapshot.errorDescription)
    }
    return QuoteOfTheDayEntry(date: date, state: .snapshot, quote: quote)
  }

  static func timelineEntries(startingAt startDate: Date) -> [QuoteOfTheDayEntry] {
    let calendar = Calendar.current
    let snapshot = cachedSnapshot()
    let candidates = snapshot.candidates
    if !candidates.isEmpty {
      let displayCandidates = candidates.sorted { lhs, rhs in
        lhs.thumbnailImage != nil && rhs.thumbnailImage == nil
      }
      Logger.quoteWidget.info(
        "Building quote widget timeline: candidates=\(candidates.count), covers=\(candidates.count { $0.thumbnailImage != nil }), firstDisplayCoverBytes=\(displayCandidates.first?.thumbnailImage?.count ?? 0)"
      )
      return displayCandidates.prefix(3).enumerated().map { offset, candidate in
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
        quote: diagnosticQuote(key: "timeline", errorDescription: snapshot.errorDescription)
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

  private struct CachedSnapshot {
    var candidates: [QuoteWidgetCandidate]
    var errorDescription: String?
  }

  private static func cachedSnapshot(store: QuoteWidgetStore = QuoteWidgetStore()) -> CachedSnapshot {
    do {
      let snapshot = try store.readSnapshot()
      Logger.quoteWidget.info(
        "Read quote widget snapshot: source=\(snapshot.sourceLibraryDisplayName, privacy: .public), candidates=\(snapshot.candidates.count), covers=\(snapshot.candidates.count { $0.thumbnailImage != nil }), firstCoverBytes=\(snapshot.candidates.first(where: { $0.thumbnailImage != nil })?.thumbnailImage?.count ?? 0)"
      )
      return CachedSnapshot(candidates: snapshot.candidates, errorDescription: nil)
    } catch {
      let errorDescription = error.localizedDescription
      Logger.quoteWidget.error("Could not read quote widget snapshot: \(errorDescription, privacy: .public)")
      return CachedSnapshot(candidates: [], errorDescription: errorDescription)
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
