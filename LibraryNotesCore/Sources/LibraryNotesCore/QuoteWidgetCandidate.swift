// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A portable quote projection stored in the widget's app-group database.
///
/// The main library database remains the source of truth. The widget database
/// contains only the fields it needs to display a quote and its cover.
public struct QuoteWidgetCandidate: Hashable, Identifiable, Sendable {
  public var id: String { "\(noteId):\(quoteKey)" }

  public var noteId: String
  public var quoteKey: String
  public var quoteText: String
  public var attributionText: String
  public var sourceTitle: String
  public var thumbnailImage: Data?
  public var selectedText: String
  public var tags: [String]

  public init(
    noteId: String,
    quoteKey: String,
    quoteText: String,
    attributionText: String,
    sourceTitle: String,
    thumbnailImage: Data? = nil,
    selectedText: String? = nil,
    tags: [String] = []
  ) {
    self.noteId = noteId
    self.quoteKey = quoteKey
    self.quoteText = quoteText
    self.attributionText = attributionText
    self.sourceTitle = sourceTitle
    self.thumbnailImage = thumbnailImage
    self.selectedText = selectedText ?? quoteText
    self.tags = tags
  }

  public init(_ quote: AttributedQuote) {
    let sourceText = String(quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace)
    let (quoteText, attributionFragment) = sourceText.decomposedChapterAndVerseAnnotation
    let sourceTitle = String(quote.title.strippingLeadingAndTrailingWhitespace)
    self.init(
      noteId: quote.noteId,
      quoteKey: quote.key,
      quoteText: quoteText,
      attributionText: Self.attributionText(title: sourceTitle, fragment: attributionFragment),
      sourceTitle: sourceTitle,
      thumbnailImage: quote.thumbnailImage,
      selectedText: quote.text
    )
  }

  private static func attributionText(title: String, fragment: String) -> String {
    let trimmedFragment = fragment
      .strippingLeadingAndTrailingWhitespace
      .dropFirst()
      .dropLast()
    if trimmedFragment.split(separator: " ").count > 1 {
      return String(trimmedFragment)
    }
    return [
      title,
      String(trimmedFragment),
    ].filter { !$0.isEmpty }.joined(separator: ", ")
  }
}

private extension String {
  var decomposedChapterAndVerseAnnotation: (quoteText: String, attributionFragment: String) {
    guard let range = range(
      of: #"\s+\([^\)]*\)\W*$"#,
      options: .regularExpression
    ) else {
      return (self, "")
    }
    var quoteText = self
    let attributionFragment = String(quoteText[range])
    quoteText.removeSubrange(range)
    return (quoteText, attributionFragment)
  }
}
