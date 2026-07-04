// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import LibraryNotesCore
import TextMarkupKit
import UIKit

@MainActor
extension Prompt {
  func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    switch self {
    case let prompt as QuestionAndAnswerPrompt:
      prompt.promptView(database: database, properties: properties)
    case let prompt as ClozePrompt:
      prompt.promptView(database: database, properties: properties)
    case let prompt as QuotePrompt:
      prompt.promptView(database: database, properties: properties)
    default:
      PromptView(frame: .zero)
    }
  }
}

@MainActor
private extension QuestionAndAnswerPrompt {
  func promptView(database: NoteDatabase, properties: CardDocumentProperties) -> PromptView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = ParsedAttributedString(string: properties.attributionMarkdown, style: .plainText(textStyle: .subheadline, textColor: .secondaryLabel, kern: 2.0))
    let formattedString = ParsedAttributedString(
      string: rawValue,
      style: .plainText(textStyle: .body, imageStorage: NoteScopedImageStorage(identifier: properties.documentName, database: database))
    )
    if let node = try? formattedString.rawString.result.get() {
      let anchoredNode = AnchoredNode(node: node, startIndex: 0)
      if let question = anchoredNode.first(where: { $0.type == .qnaQuestion }) {
        view.front = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: question.range)).trimmingTrailingWhitespace()
      }
      if let answer = anchoredNode.first(where: { $0.type == .qnaAnswer }) {
        view.back = formattedString.attributedSubstring(from: formattedString.range(forRawStringRange: answer.range)).trimmingTrailingWhitespace()
      }
    }
    return view
  }
}

@MainActor
private extension QuotePrompt {
  func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    let view = TwoSidedCardView(frame: .zero)
    view.context = NSAttributedString(
      string: "Identify the source".uppercased(),
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .subheadline),
        .foregroundColor: UIColor.secondaryLabel,
        .kern: 2.0,
      ]
    )
    let (front, chapterAndVerse) = renderCardFront(imageStorage: NoteScopedImageStorage(identifier: properties.documentName, database: database))
    view.front = front.trimmingTrailingWhitespace()
    let attribution = ParsedAttributedString(string: "-" + properties.attributionMarkdown + " " + chapterAndVerse, style: .plainText(textStyle: .caption1))
    let back = NSMutableAttributedString()
    back.append(front.trimmingTrailingWhitespace())
    back.append(ParsedAttributedString(string: "\n\n", style: .plainText(textStyle: .caption1)))
    back.append(attribution.trimmingTrailingWhitespace())
    view.back = back
    return view
  }

  func renderCardFront(
    imageStorage: NoteScopedImageStorage?
  ) -> (front: NSAttributedString, chapterAndVerse: Substring) {
    let renderedMarkdown = ParsedAttributedString(string: rawValue, style: .plainText(textStyle: .body, imageStorage: imageStorage))
    let chapterAndVerse = renderedMarkdown.chapterAndVerseAnnotation ?? ""
    let front = renderedMarkdown.removingChapterAndVerseAnnotation()
    return (front: front, chapterAndVerse: chapterAndVerse)
  }
}

@MainActor
private extension ClozePrompt {
  func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    let cardView = TwoSidedCardView(frame: .zero)
    cardView.context = context()
    let baseSettings = ParsedAttributedString.Style.plainText(textStyle: .body)
      .renderingImages(from: NoteScopedImageStorage(identifier: properties.documentName, database: database))
    let (front, chapterAndVerse) = ParsedAttributedString(
      string: markdown,
      style: baseSettings.hidingCloze(at: clozeIndex)
    ).decomposedChapterAndVerseAnnotation
    cardView.front = front.trimmingTrailingWhitespace()
    let back = NSMutableAttributedString()
    back.append(
      ParsedAttributedString(string: markdown, style: baseSettings.highlightingCloze(at: clozeIndex))
        .removingChapterAndVerseAnnotation()
        .trimmingTrailingWhitespace()
    )
    if !properties.attributionMarkdown.isEmpty {
      let attribution = ParsedAttributedString(
        string: "\n\n-" + properties.attributionMarkdown + " " + chapterAndVerse,
        style: .plainText(textStyle: .caption1)
      )
      back.append(attribution.trimmingTrailingWhitespace())
    }
    cardView.back = back
    return cardView
  }

  func context() -> NSAttributedString {
    let font = UIFont.preferredFont(forTextStyle: .subheadline)
    let contextString = "Fill in the blank"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor.secondaryLabel]
    )
  }
}

private final class HidingClozeFormatter: ParsedAttributedStringFormatter {
  init(index: Int) {
    self.index = index
  }

  let index: Int
  var replaceClozeCount = 0

  func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    var attributes = currentAttributes
    let shouldHide = replaceClozeCount == index
    replaceClozeCount += 1
    if shouldHide {
      attributes.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
      let hintNode = AnchoredNode(node: node, startIndex: offset).first(where: { $0.type == .clozeHint })
      let hintChars = hintNode.flatMap { buffer[$0.range] } ?? []
      let hint = String(utf16CodeUnits: hintChars, count: hintChars.count)
      if hint.strippingLeadingAndTrailingWhitespace.isEmpty {
        attributes.color = .clear
        if let answerNode = AnchoredNode(node: node, startIndex: offset).first(where: { $0.type == .clozeAnswer }) {
          return (attributes, buffer[answerNode.range])
        } else {
          return (attributes, nil)
        }
      } else {
        attributes.color = .secondaryLabel
        return (attributes, Array(hint.utf16))
      }
    } else {
      if let answerNode = AnchoredNode(node: node, startIndex: offset).first(where: { $0.type == .clozeAnswer }) {
        return (attributes, buffer[answerNode.range])
      } else {
        assertionFailure()
        return (attributes, [])
      }
    }
  }
}

private final class HighlightingClozeFormatter: ParsedAttributedStringFormatter {
  let index: Int
  var formatClozeCount = 0

  init(index: Int) { self.index = index }

  func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    let shouldHighlight = formatClozeCount == index
    formatClozeCount += 1
    if shouldHighlight {
      var attributes = currentAttributes
      attributes.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
      return (attributes, nil)
    } else {
      return (currentAttributes, nil)
    }
  }
}

private extension ParsedAttributedString.Style {
  func hidingCloze(at index: Int) -> Self {
    var settings = self
    settings.formatters[.cloze] = AnyParsedAttributedStringFormatter(HidingClozeFormatter(index: index))
    return settings
  }

  func highlightingCloze(at index: Int) -> Self {
    var settings = self
    settings.formatters[.cloze] = AnyParsedAttributedStringFormatter(HighlightingClozeFormatter(index: index))
    return settings
  }
}
