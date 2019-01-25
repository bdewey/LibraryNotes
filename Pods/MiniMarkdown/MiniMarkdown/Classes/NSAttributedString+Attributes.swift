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

import CocoaLumberjack
import UIKit

extension Dictionary where Key == NSAttributedString.Key {
  public var font: UIFont? {
    return self[.font] as? UIFont
  }
}

public extension NSAttributedString {

  /// An abstract description of NSAttributedString attributes.
  public struct Attributes {

    /// The family name of the NSAttributedStringKey.font attribute.
    public var familyName: String

    /// If true, use a bold variant of the font.
    public var bold: Bool

    /// If true, use an italic variant of the font.
    public var italic: Bool

    /// The desired font size.
    public var fontSize: CGFloat

    /// Desired letter spacing.
    public var kern: CGFloat = 0

    /// The value for NSAttributedStringKey.color. If nil, this attribute will not
    /// be present.
    public var color: UIColor?

    /// The value for NSAttributedStringKey.backgroundColor. If nil, the attribute
    /// will not be present.
    public var backgroundColor: UIColor?

    /// If true, create a tab stop and appropriate indentation for the "hanging indent" of a list.
    public var listLevel = 0

    public var headIndent: CGFloat = 0

    public var tailIndent: CGFloat = 0

    public var firstLineHeadIndent: CGFloat = 0

    public var alignment: NSTextAlignment?

    public var lineHeightMultiple: CGFloat? = 1.2

    /// Initializer.
    /// - parameter font: The UIFont that determines the base values of this set of attributes.
    public init(_ font: UIFont) {
      self.color = nil
      self.familyName = font.familyName
      self.fontSize = font.pointSize
      let fontDescriptor = font.fontDescriptor
      self.italic = fontDescriptor.symbolicTraits.contains(.traitItalic)
      self.bold = fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    public static let keys: [NSAttributedString.Key] = [
      .foregroundColor,
      .font,
      .paragraphStyle
    ]

    /// An NSAttributedString attributes dictionary based on the values of the structure.
    public var attributes: [NSAttributedString.Key: Any] {
      var result: [NSAttributedString.Key: Any] = [:]
      if let color = self.color {
        result[.foregroundColor] = color
      }
      if let backgroundColor = backgroundColor {
        result[.backgroundColor] = backgroundColor
      }
      var traits = UIFontDescriptor.SymbolicTraits()
      if italic {
        traits.formUnion(.traitItalic)
      }
      if bold {
        traits.formUnion(.traitBold)
      }
      let baseDescriptor = UIFontDescriptor(name: familyName, size: fontSize)
      if let descriptor = baseDescriptor.withSymbolicTraits(traits) {
        result[.font] = UIFont(descriptor: descriptor, size: 0)
      } else {
        DDLogWarn("Couldn't find a font with traits for \(familyName), size = \(fontSize), traits = \(traits)")
        result[.font] = UIFont(descriptor: baseDescriptor, size: 0)
      }
      if kern != 0 {
        result[.kern] = kern
      }
      var didCustomizeParagraphStyle = false
      let paragraphStyle = NSMutableParagraphStyle()
      if let lineHeightMultiple = lineHeightMultiple {
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        didCustomizeParagraphStyle = true
      }
      if headIndent != 0 {
        paragraphStyle.headIndent = headIndent
        didCustomizeParagraphStyle = true
      }
      if tailIndent != 0 {
        paragraphStyle.tailIndent = tailIndent
        didCustomizeParagraphStyle = true
      }
      if firstLineHeadIndent != 0 {
        paragraphStyle.firstLineHeadIndent = firstLineHeadIndent
        didCustomizeParagraphStyle = true
      }
      if let alignment = alignment {
        paragraphStyle.alignment = alignment
        didCustomizeParagraphStyle = true
      }
      if listLevel > 0 {
        let indentAmountPerLevel: CGFloat = headIndent > 0 ? headIndent : 16
        paragraphStyle.headIndent = indentAmountPerLevel * CGFloat(listLevel)
        paragraphStyle.firstLineHeadIndent = indentAmountPerLevel * CGFloat(listLevel - 1)
        var tabStops: [NSTextTab] = []
        for i in 0 ..< 4 {
          let listTab = NSTextTab(
            textAlignment: .natural,
            location: paragraphStyle.headIndent + CGFloat(i) * indentAmountPerLevel,
            options: [:]
          )
          tabStops.append(listTab)
        }
        paragraphStyle.tabStops = tabStops
        didCustomizeParagraphStyle = true
      }
      if didCustomizeParagraphStyle {
        result[.paragraphStyle] = paragraphStyle
      }
      return result
    }
  }
}
