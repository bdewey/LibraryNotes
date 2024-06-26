// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
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
      Logger.layoutManager.debug("Drawing a vertical bar")
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
