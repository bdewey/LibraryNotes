//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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

  /// Creates a renderer that will render `markdown` with the cloze at `clozeIndex` removed,
  /// replaced with a hint if present, and highlighted.
  public var cardFrontSettings: ParsedAttributedString.Settings {
    .clozeRenderer(hidingClozeAt: clozeIndex)
  }
}

extension ClozePrompt: Prompt {
  public func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView {
    let cardView = TwoSidedCardView(frame: .zero)
    cardView.context = context()
    let (front, chapterAndVerse) = ParsedAttributedString(string: markdown, settings: cardFrontSettings).decomposedChapterAndVerseAnnotation
    cardView.front = front.trimmingTrailingWhitespace()
    let back = NSMutableAttributedString()
    back.append(
      ParsedAttributedString(string: markdown, settings: .clozeRenderer(highlightingClozeAt: clozeIndex))
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

extension ParsedAttributedString.Settings {
  static func clozeRenderer(hidingClozeAt index: Int) -> ParsedAttributedString.Settings {
    var settings = ParsedAttributedString.Settings.plainText(textStyle: .body)
    var replaceClozeCount = 0
    settings.replacementFunctions[.cloze] = { node, startIndex, buffer in
      let shouldHide = replaceClozeCount == index
      replaceClozeCount += 1
      if shouldHide {
        let hintNode = AnchoredNode(node: node, startIndex: startIndex).first(where: { $0.type == .clozeHint })
        let hintChars = hintNode.flatMap { buffer[$0.range] } ?? []
        let hint = String(utf16CodeUnits: hintChars, count: hintChars.count)
        if hint.strippingLeadingAndTrailingWhitespace.isEmpty {
          return Array("   ".utf16)
        } else {
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

  static func clozeRenderer(highlightingClozeAt index: Int) -> ParsedAttributedString.Settings {
    var settings = ParsedAttributedString.Settings.plainText(textStyle: .body)
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

// extension MarkdownAttributedStringRenderer {
//  /// Builds a renderer that will replace the cloze at clozeIndex with its hint and
//  /// highlight the cloze.
//  static func cardFront(
//    hideClozeAt index: Int
//  ) -> MarkdownAttributedStringRenderer {
//    var renderer = MarkdownAttributedStringRenderer(textStyle: .body)
//    var renderedCloze = 0
//    renderer.renderFunctions[.cloze] = { node, attributes in
//      guard let cloze = node as? Cloze else { return NSAttributedString() }
//      let shouldHide = renderedCloze == index
//      renderedCloze += 1
//      if shouldHide {
//        if cloze.hint.strippingLeadingAndTrailingWhitespace.isEmpty {
//          // There is no real hint. So instead put the hidden text but render it using the
//          // background color. That way it takes up the correct amount of space in the string,
//          // but is still invisible.
//          var attributes = attributes.withClozeHighlight
//          attributes[.foregroundColor] = UIColor.clear
//          return NSAttributedString(string: String(cloze.hiddenText), attributes: attributes)
//        } else {
//          return NSAttributedString(
//            string: String(cloze.hint),
//            attributes: attributes.withClozeHighlight
//          )
//        }
//      } else {
//        return NSAttributedString(
//          string: String(cloze.hiddenText),
//          attributes: attributes
//        )
//      }
//    }
//    return renderer
//  }
//
//  /// Builds a renderer that will show and highlight the cloze at clozeIndex.
//  static func cardBackRenderer(
//    revealingClozeAt index: Int
//  ) -> MarkdownAttributedStringRenderer {
//    var renderer = MarkdownAttributedStringRenderer(textStyle: .body)
//    var localClozeAttributes = renderer.defaultAttributes.withClozeHighlight
//    localClozeAttributes[.foregroundColor] = UIColor.label
//    var renderedCloze = 0
//    renderer.renderFunctions[.cloze] = { node, attributes in
//      let finalAttributes = renderedCloze == index ? attributes.withClozeHighlight : attributes
//      renderedCloze += 1
//      guard let cloze = node as? Cloze else { return NSAttributedString() }
//      return NSAttributedString(string: String(cloze.hiddenText), attributes: finalAttributes)
//    }
//    return renderer
//  }
// }
//
// private let clozeRenderer: MarkdownAttributedStringRenderer = {
//  var renderer = MarkdownAttributedStringRenderer.textOnly
//  renderer.renderFunctions[.cloze] = { node, _ in
//    guard let cloze = node as? Cloze else { return NSAttributedString() }
//    return NSAttributedString(string: String(cloze.hiddenText))
//  }
//  return renderer
// }()

private extension AttributedStringAttributes {
  var withClozeHighlight: AttributedStringAttributes {
    var copy = self
    copy[.foregroundColor] = UIColor.secondaryLabel
    copy[.backgroundColor] = UIColor.systemYellow.withAlphaComponent(0.3)
    return copy
  }
}
