// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Foundation
import Logging
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
    let baseSettings = ParsedAttributedString.Settings.plainText(textStyle: .body).renderingImages(from: database)
    let (front, chapterAndVerse) = ParsedAttributedString(
      string: markdown,
      settings: baseSettings.hidingCloze(at: clozeIndex)
    ).decomposedChapterAndVerseAnnotation
    cardView.front = front.trimmingTrailingWhitespace()
    let back = NSMutableAttributedString()
    back.append(
      ParsedAttributedString(string: markdown, settings: baseSettings.highlightingCloze(at: clozeIndex))
        .removingChapterAndVerseAnnotation()
        .trimmingTrailingWhitespace()
    )
    if !properties.attributionMarkdown.isEmpty {
      back.append(NSAttributedString(string: "\n\n"))
      let attribution = ParsedAttributedString(
        string: "—" + properties.attributionMarkdown + " " + chapterAndVerse,
        settings: .plainText(textStyle: .caption1)
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

private extension ParsedAttributedString.Settings {
  func hidingCloze(at index: Int) -> Self {
    var settings = self
    var replaceClozeCount = 0
    settings.replacementFunctions[.cloze] = { node, startIndex, buffer, attributes in
      let shouldHide = replaceClozeCount == index
      replaceClozeCount += 1
      if shouldHide {
        attributes[.backgroundColor] = UIColor.systemYellow.withAlphaComponent(0.3)
        let hintNode = AnchoredNode(node: node, startIndex: startIndex).first(where: { $0.type == .clozeHint })
        let hintChars = hintNode.flatMap { buffer[$0.range] } ?? []
        let hint = String(utf16CodeUnits: hintChars, count: hintChars.count)
        if hint.strippingLeadingAndTrailingWhitespace.isEmpty {
          attributes[.foregroundColor] = attributes[.backgroundColor]
          if let answerNode = AnchoredNode(node: node, startIndex: startIndex).first(where: { $0.type == .clozeAnswer }) {
            return buffer[answerNode.range]
          } else {
            return nil
          }
        } else {
          attributes[.foregroundColor] = UIColor.secondaryLabel
          return Array(hint.utf16)
        }
      } else {
        if let answerNode = AnchoredNode(node: node, startIndex: startIndex).first(where: { $0.type == .clozeAnswer }) {
          return buffer[answerNode.range]
        } else {
          assertionFailure()
          return []
        }
      }
    }

    var formatClozeCount = 0
    settings.formattingFunctions[.cloze] = { _, attributes in
      let shouldHighlight = formatClozeCount == index
      formatClozeCount += 1
      if shouldHighlight {
        attributes[.foregroundColor] = UIColor.secondaryLabel
        attributes[.backgroundColor] = UIColor.systemYellow.withAlphaComponent(0.3)
      }
    }
    return settings
  }

  func highlightingCloze(at index: Int) -> Self {
    var settings = self
    var formatClozeCount = 0
    settings.formattingFunctions[.cloze] = { _, attributes in
      let shouldHighlight = formatClozeCount == index
      formatClozeCount += 1
      if shouldHighlight {
        attributes[.backgroundColor] = UIColor.systemYellow.withAlphaComponent(0.3)
      }
    }
    return settings
  }
}
