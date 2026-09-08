// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import LibraryNotesCore
import os
import UIKit

private extension Logger {
  static var layoutManager: Logger {
    Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LayoutManager")
  }
}

/// Custom layout manager that knows how to draw vertical bars next to block quotes.
/// Implementation inspired by the Wordpress Aztec HTML editing component:
/// https://github.com/wordpress-mobile/AztecEditor-iOS/blob/develop/Aztec/Classes/TextKit/LayoutManager.swift
final class LayoutManager: NSLayoutManager {
  /// Toggle this while evaluating whether the quote rail helps or competes with the share badge.
  var shouldDrawRail = false

  private var temporaryHighlight: (range: NSRange, color: UIColor)?

  func setTemporaryHighlight(range: NSRange, color: UIColor) {
    if let temporaryHighlight {
      invalidateDisplay(forCharacterRange: temporaryHighlight.range)
    }
    temporaryHighlight = (range, color)
    invalidateDisplay(forCharacterRange: range)
  }

  func clearTemporaryHighlight() {
    guard let temporaryHighlight else { return }
    self.temporaryHighlight = nil
    let textLength = textStorage?.length ?? 0
    guard temporaryHighlight.range.location < textLength else { return }
    invalidateDisplay(forCharacterRange: NSRange(
      location: temporaryHighlight.range.location,
      length: min(temporaryHighlight.range.length, textLength - temporaryHighlight.range.location)
    ))
  }

  override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    drawTemporaryHighlight(forGlyphRange: glyphsToShow, at: origin)
    drawBlockquotes(forGlyphRange: glyphsToShow, at: origin)
  }

  override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
    drawBlockquoteShareBadges(forGlyphRange: glyphsToShow, at: origin)
  }
}

// MARK: - Private

private extension LayoutManager {
  func drawTemporaryHighlight(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard
      let temporaryHighlight,
      let context = UIGraphicsGetCurrentContext(),
      let textContainer = textContainers.first
    else { return }
    let highlightGlyphRange = glyphRange(
      forCharacterRange: temporaryHighlight.range,
      actualCharacterRange: nil
    )
    let visibleHighlightRange = NSIntersectionRange(glyphsToShow, highlightGlyphRange)
    guard visibleHighlightRange.length > 0 else { return }
    temporaryHighlight.color.setFill()
    enumerateLineFragments(forGlyphRange: visibleHighlightRange) { _, _, _, lineGlyphRange, _ in
      let glyphRange = NSIntersectionRange(lineGlyphRange, visibleHighlightRange)
      guard glyphRange.length > 0 else { return }
      let rect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        .offsetBy(dx: origin.x, dy: origin.y)
      context.fill(rect)
    }
  }

  /// Text with a `.blockquoteBorderColor` attribute gets rendered as a block quote:
  /// - The background is `quaternarySystemFill`
  /// - When `shouldDrawRail` is true, a 4 point border on the left edge is filled with
  ///   `blockquoteBorderColor`
  func drawBlockquotes(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard let textStorage else {
      return
    }

    guard let context = UIGraphicsGetCurrentContext() else {
      preconditionFailure("When drawBackgroundForGlyphRange is called, the graphics context is supposed to be set by UIKit")
    }

    let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
    textStorage.enumerateAttribute(.blockquoteBorderColor, in: characterRange, options: []) { object, range, _ in
      guard let color = object as? UIColor else {
        return
      }
      let verticalBarGlyphRange = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
      enumerateLineFragments(forGlyphRange: verticalBarGlyphRange) { rect, _, _, _, _ in
        var blockquoteRect = rect.offsetBy(dx: origin.x, dy: origin.y)
        UIColor.quaternarySystemFill.setFill()
        context.fill(blockquoteRect)
        guard self.shouldDrawRail else { return }
        blockquoteRect.size.width = 4
        color.setFill()
        context.fill(blockquoteRect)
      }
    }
  }

  /// Draws a share badge over the Markdown delimiter on the first line of each quote.
  /// The editor handles taps in the surrounding rail as a request to share the quote.
  func drawBlockquoteShareBadges(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard
      let textStorage,
      textStorage.length > 0,
      UIGraphicsGetCurrentContext() != nil
    else { return }

    let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
    textStorage.enumerateAttribute(.blockquoteBorderColor, in: characterRange, options: []) { _, range, _ in
      var quoteRange = NSRange()
      guard
        let color = textStorage.attribute(
          .blockquoteBorderColor,
          at: range.location,
          longestEffectiveRange: &quoteRange,
          in: NSRange(location: 0, length: textStorage.length)
        ) as? UIColor
      else { return }
      let quoteGlyphRange = glyphRange(forCharacterRange: quoteRange, actualCharacterRange: nil)
      guard quoteGlyphRange.length > 0 else { return }

      var firstLineGlyphRange = NSRange()
      let firstLineRect = lineFragmentRect(
        forGlyphAt: quoteGlyphRange.location,
        effectiveRange: &firstLineGlyphRange
      )
      guard NSIntersectionRange(firstLineGlyphRange, glyphsToShow).length > 0 else { return }

      drawShareBadge(in: firstLineRect.offsetBy(dx: origin.x, dy: origin.y), color: color)
    }
  }

  func drawShareBadge(in lineFragmentRect: CGRect, color: UIColor) {
    let diameter = min(max(lineFragmentRect.height - 6, 22), 30)
    let badgeRect = CGRect(
      x: lineFragmentRect.minX + 16 - diameter / 2,
      y: lineFragmentRect.midY - diameter / 2,
      width: diameter,
      height: diameter
    )
    UIColor.grailBackground.setFill()
    let badgePath = UIBezierPath(ovalIn: badgeRect)
    badgePath.fill()
    badgePath.lineWidth = 1.5
    color.setStroke()
    badgePath.stroke()

    let configuration = UIImage.SymbolConfiguration(pointSize: diameter * 0.48, weight: .medium)
    guard let symbol = UIImage(systemName: "square.and.arrow.up", withConfiguration: configuration)?
      .withTintColor(color, renderingMode: .alwaysOriginal)
    else { return }
    let availableRect = badgeRect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22)
    let scale = min(availableRect.width / symbol.size.width, availableRect.height / symbol.size.height)
    let symbolSize = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
    symbol.draw(in: CGRect(
      x: availableRect.midX - symbolSize.width / 2,
      y: availableRect.midY - symbolSize.height / 2,
      width: symbolSize.width,
      height: symbolSize.height
    ))
  }
}
