// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

public struct QuoteListView: View {
  private let quotes: [QuoteDisplayModel]
  private let onViewBook: ((QuoteDisplayModel) -> Void)?
  private let onShare: ((QuoteDisplayModel) -> Void)?

  public init(
    quotes: [QuoteDisplayModel],
    onViewBook: ((QuoteDisplayModel) -> Void)? = nil,
    onShare: ((QuoteDisplayModel) -> Void)? = nil
  ) {
    self.quotes = quotes
    self.onViewBook = onViewBook
    self.onShare = onShare
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(quotes) { quote in
          QuoteCardView(model: quote)
            .padding(.vertical, 24)
            .contextMenu {
              if let onViewBook {
                Button {
                  onViewBook(quote)
                } label: {
                  Label("View Book", systemImage: "book")
                }
              }

              if let onShare {
                Button {
                  onShare(quote)
                } label: {
                  Label("Share", systemImage: "square.and.arrow.up")
                }
              }
            }
        }
      }
      .padding(.horizontal, 8)
    }
    .background(Color.grailBackground)
    .scrollContentBackground(.hidden)
  }
}

public extension Color {
  #if canImport(UIKit)
    static let grailBackground = Color(
      UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
          ? UIColor(red: 0.098, green: 0.094, blue: 0.082, alpha: 1)
          : UIColor(red: 1, green: 0xF3 / 255, blue: 0xD2 / 255, alpha: 1)
      }
    )
  #else
    static let grailBackground = Color(red: 1, green: 0xF3 / 255, blue: 0xD2 / 255)
  #endif
}

#Preview {
  QuoteListView(
    quotes: [
      QuoteDisplayModel(
        noteId: "preview",
        key: "one",
        quoteText: "There are no binding oaths between men and lions.",
        attributionText: "The Iliad, 22.310"
      ),
      QuoteDisplayModel(
        noteId: "preview",
        key: "two",
        quoteText: "...true education consists precisely in this, in learning to wish that everything should come about just as it does.",
        attributionText: "Discourses, Fragments, Handbook, 1.12.15"
      ),
    ]
  )
}
