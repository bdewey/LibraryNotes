// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import LibraryNotesCore
import TextMarkupKit

public struct QuoteDisplayModel: Identifiable, Equatable, Sendable {
  public var id: String { "\(noteId):\(key)" }

  public let noteId: String
  public let key: String
  public let quoteText: String
  public let attributionText: String
  public let thumbnailImage: Data?
  public let selectedText: String

  public init(
    noteId: String,
    key: String,
    quoteText: String,
    attributionText: String,
    thumbnailImage: Data? = nil,
    selectedText: String? = nil
  ) {
    self.noteId = noteId
    self.key = key
    self.quoteText = quoteText
    self.attributionText = attributionText
    self.thumbnailImage = thumbnailImage
    self.selectedText = selectedText ?? quoteText
  }

  public init(_ quote: AttributedQuote) {
    let sourceText = String(quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace)
    let (displayText, attributionFragment) = sourceText.decomposedChapterAndVerseAnnotation
    let attributionText = Self.attributionText(
      title: String(quote.title.strippingLeadingAndTrailingWhitespace),
      fragment: attributionFragment
    )
    self.init(
      noteId: quote.noteId,
      key: quote.key,
      quoteText: displayText,
      attributionText: attributionText,
      thumbnailImage: quote.thumbnailImage,
      selectedText: quote.text
    )
  }

  public init(_ candidate: QuoteWidgetCandidate) {
    self.init(
      noteId: candidate.noteId,
      key: candidate.quoteKey,
      quoteText: candidate.quoteText,
      attributionText: candidate.attributionText,
      selectedText: candidate.selectedText
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

public extension QuoteDisplayModel {
  var attributedQuoteText: AttributedString {
    Self.attributedString(quoteText, textStyle: .body, fontDesign: .quoteFontDesign)
  }

  var attributedAttributionText: AttributedString {
    AttributedString(attributionText)
  }

  private static func attributedString(
    _ string: String,
    textStyle: TextMarkupKitTextStyle,
    fontDesign: TextMarkupKitFontDesign = .default
  ) -> AttributedString {
    let parsedString = ParsedAttributedString(
      string: string,
      style: .plainText(textStyle: textStyle, fontDesign: fontDesign)
    )
    return AttributedString(parsedString)
  }
}

private extension TextMarkupKitFontDesign {
  static var quoteFontDesign: TextMarkupKitFontDesign {
    #if canImport(UIKit)
      .serif
    #else
      .default
    #endif
  }
}
