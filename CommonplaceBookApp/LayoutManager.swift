// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import Logging
import MiniMarkdown
import UIKit

private let logger = Logger(label: "org.brians-brian.CommonplaceBookApp.LayoutManager")

/// Custom layout manager that knows how to draw vertical bars next to block quotes.
/// Implementation inspired by the Wordpress Aztec HTML editing component:
/// https://github.com/wordpress-mobile/AztecEditor-iOS/blob/develop/Aztec/Classes/TextKit/LayoutManager.swift
final class LayoutManager: NSLayoutManager {
  override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    drawBlockquotes(forGlyphRange: glyphsToShow, at: origin)
  }
}

// MARK: - Private

private extension LayoutManager {
  /// Text with a `.blockquoteBorderColor` attribute gets rendered as a block quote:
  /// - The background is `quaternarySystemFill`
  /// - A 4 point border on the left edge is filled with `blockquoteBorderColor`
  func drawBlockquotes(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard let textStorage = textStorage else {
      return
    }

    guard let context = UIGraphicsGetCurrentContext() else {
      preconditionFailure("When drawBackgroundForGlyphRange is called, the graphics context is supposed to be set by UIKit")
    }

    let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
    textStorage.enumerateAttribute(.blockquoteBorderColor, in: characterRange, options: []) { object, range, _ in
      guard let color = object as? UIColor else {
        return
      }
      logger.debug("Drawing a vertical bar")
      let verticalBarGlyphRange = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
      enumerateLineFragments(forGlyphRange: verticalBarGlyphRange) { rect, _, _, _, _ in
        var verticalBarRect = rect.offsetBy(dx: origin.x, dy: origin.y)
        UIColor.quaternarySystemFill.setFill()
        context.fill(verticalBarRect)
        verticalBarRect.size.width = 4
        color.setFill()
        context.fill(verticalBarRect)
      }
    }
  }
}
