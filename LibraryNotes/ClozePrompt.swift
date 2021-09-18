// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Foundation
import Logging
import TextMarkupKit
import UIKit

/// A Card for remembering a sentence with a word/phrase removed and optionally replaced with
/// a hint. The removed word/phrase is a "cloze".
///
/// See https://en.wikipedia.org/wiki/Cloze_test
public struct ClozePrompt {
  /// Designated initializer.
  ///
  /// - parameter markdown: The markdown content that contains at least one cloze.
  /// - parameter closeIndex: The index of the cloze in `markdown` to remove when testing.
  public init(template: ClozePromptCollection, markdown: String, clozeIndex: Int) {
    self.markdown = markdown
    self.clozeIndex = clozeIndex
  }

  /// The markdown content that contains at least one cloze.
  public let markdown: String

  /// The index of the cloze in `markdown` to remove when testing.
  public let clozeIndex: Int
}

extension ClozePrompt: Prompt {
  public func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    let cardView = TwoSidedCardView(frame: .zero)
    cardView.context = context()
    let baseSettings = ParsedAttributedString.Style.plainText(textStyle: .body)
      .renderingImages(from: BoundNote(identifier: properties.documentName, database: database))
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
      back.append(NSAttributedString(string: "\n\n"))
      let attribution = ParsedAttributedString(
        string: "—" + properties.attributionMarkdown + " " + chapterAndVerse,
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

final class HidingClozeFormatter: ParsedAttributedStringFormatter {
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
        // There is no hint. We're going to show a blank.
        // The only question is: How big is the blank? Try to make it the size of the answer.
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

final class HighlightingClozeFormatter: ParsedAttributedStringFormatter {
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

extension ParsedAttributedString.Style {
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
