// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public extension NSAttributedString.Key {
  
  /// If this attribute is set on a space inside an NSAttributedString,
  /// TreatAsTabLayoutManagerDelegate will lay out that space like a tab character.
  public static let treatAsTab = NSAttributedString.Key(rawValue: "minimarkdown_treatAsTab")
}

fileprivate struct GlyphBuffers {
  
  var glyphBuffer: [CGGlyph] = []
  var propBuffer: [NSLayoutManager.GlyphProperty] = []
  var charIndexBuffer: [Int] = []
  
  init(
    count: Int,
    glyphs: UnsafePointer<CGGlyph>,
    properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
    characterIndexes: UnsafePointer<Int>
  ) {
    for index in 0 ..< count {
      glyphBuffer.append(glyphs[index])
      propBuffer.append(properties[index])
      charIndexBuffer.append(characterIndexes[index])
    }
  }
}

/// A NSLayoutManagerDelegate that knows how to lay out 0x20 unichar values with the
/// `NSAtttributedString.Key.treatAsTab` attribute as horizontal tabs.
public class TreatAsTabLayoutManagerDelegate: NSObject, NSLayoutManagerDelegate {
  
  /// Does glyph property substitution... looks for treatAsTab characters and
  /// changes the glyph to have a `.controlCharacter` property.
  /// (Spaces are `.elastic`)
  public func layoutManager(
    _ layoutManager: NSLayoutManager,
    shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
    properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
    characterIndexes charIndexes: UnsafePointer<Int>,
    font aFont: UIFont,
    forGlyphRange glyphRange: NSRange
    ) -> Int {
    guard let textStorage = layoutManager.textStorage else { return 0 }
    let nsstring = NSString(string: textStorage.string)
    var buffer: GlyphBuffers?
    for index in 0 ..< glyphRange.length {
      guard
        nsstring.character(at: charIndexes[index]) == 0x20,
        nil != textStorage.attribute(
          .treatAsTab,
          at: charIndexes[index],
          effectiveRange: nil
        )
        else {
          continue
      }
      var unichar = kCGFontIndexInvalid
      var glyph = CGGlyph()
      CTFontGetGlyphsForCharacters(aFont, &unichar, &glyph, 1)
      if buffer == nil {
        buffer = GlyphBuffers(
          count: glyphRange.length,
          glyphs: glyphs,
          properties: props,
          characterIndexes: charIndexes
        )
      }
      buffer!.glyphBuffer[index] = glyph
      buffer!.propBuffer[index] = .controlCharacter
    }
    if let buffer = buffer {
      layoutManager.setGlyphs(
        buffer.glyphBuffer,
        properties: buffer.propBuffer,
        characterIndexes: buffer.charIndexBuffer,
        font: aFont,
        forGlyphRange: glyphRange
      )
      return glyphRange.length
    } else {
      return 0
    }
  }
  
  /// Instructs the layout manager to treat the control character corresponding
  /// with .treatAsTab characters as .horizontalTab.
  public func layoutManager(
    _ layoutManager: NSLayoutManager,
    shouldUse action: NSLayoutManager.ControlCharacterAction,
    forControlCharacterAt charIndex: Int
    ) -> NSLayoutManager.ControlCharacterAction {
    if nil != layoutManager.textStorage?.attribute(
      .treatAsTab,
      at: charIndex,
      effectiveRange: nil
      ) {
      return .horizontalTab
    } else {
      return action
    }
  }
}

