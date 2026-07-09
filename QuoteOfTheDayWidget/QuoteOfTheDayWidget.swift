// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesUI
import SwiftUI
import WidgetKit

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
    QuoteOfTheDayEntry(
      date: date,
      state: .snapshot,
      quote: QuoteDisplayModel(
        noteId: "snapshot-preview",
        key: "austen",
        quoteText: "There is a stubbornness about me that never can bear to be frightened at the will of others.",
        attributionText: "Jane Austen, Pride and Prejudice"
      )
    )
  }

  static func timelineEntries(startingAt startDate: Date) -> [QuoteOfTheDayEntry] {
    let calendar = Calendar.current
    return [
      timelineEntry(
        date: startDate,
        key: "tolkien",
        quoteText: "The road goes ever on and on",
        attributionText: "J.R.R. Tolkien, The Lord of the Rings"
      ),
      timelineEntry(
        date: calendar.date(byAdding: .minute, value: 15, to: startDate) ?? startDate,
        key: "aurelius",
        quoteText: "The impediment to action advances action. What stands in the way becomes the way.",
        attributionText: "Marcus Aurelius, Meditations"
      ),
      timelineEntry(
        date: calendar.date(byAdding: .minute, value: 30, to: startDate) ?? startDate,
        key: "dickinson",
        quoteText: "Forever is composed of nows.",
        attributionText: "Emily Dickinson"
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
