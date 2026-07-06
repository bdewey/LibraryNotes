// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesUI
import SwiftUI
import WidgetKit

struct QuoteOfTheDayEntry: TimelineEntry {
  let date: Date
  let quote: QuoteDisplayModel
}

struct QuoteOfTheDayProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuoteOfTheDayEntry {
    Self.staticEntry
  }

  func getSnapshot(in context: Context, completion: @escaping (QuoteOfTheDayEntry) -> Void) {
    completion(Self.staticEntry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteOfTheDayEntry>) -> Void) {
    completion(Timeline(entries: [Self.staticEntry], policy: .never))
  }

  private static var staticEntry: QuoteOfTheDayEntry {
    QuoteOfTheDayEntry(
      date: .now,
      quote: QuoteDisplayModel(
        noteId: "static-preview",
        key: "tolkien",
        quoteText: "The road goes ever on and on",
        attributionText: "J.R.R. Tolkien, The Lord of the Rings"
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
  QuoteOfTheDayEntry(
    date: .now,
    quote: QuoteDisplayModel(
      noteId: "static-preview",
      key: "tolkien",
      quoteText: "The road goes ever on and on",
      attributionText: "J.R.R. Tolkien, The Lord of the Rings"
    )
  )
}
