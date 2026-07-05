// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI
import WidgetKit

struct QuoteOfTheDayEntry: TimelineEntry {
  let date: Date
  let quote: String
  let attribution: String
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
      quote: "The road goes ever on and on",
      attribution: "J.R.R. Tolkien, The Lord of the Rings"
    )
  }
}

struct QuoteOfTheDayWidgetView: View {
  let entry: QuoteOfTheDayEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.quote)
        .font(.headline)
        .fontDesign(.serif)
        .lineLimit(4)
        .minimumScaleFactor(0.8)

      Text(entry.attribution)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(.background, for: .widget)
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
    quote: "The road goes ever on and on",
    attribution: "J.R.R. Tolkien, The Lord of the Rings"
  )
}
