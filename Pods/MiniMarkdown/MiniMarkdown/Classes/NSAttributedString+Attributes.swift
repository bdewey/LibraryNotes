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

    public func settingBold() -> Attributes {
      var copy = self
      copy.bold = true
      return copy
    }

    /// If true, use an italic variant of the font.
    public var italic: Bool

    public func settingItalic() -> Attributes {
      var copy = self
      copy.italic = true
      return copy
    }

    /// The desired font size.
    public var fontSize: CGFloat

    public func settingFontSize(_ size: CGFloat) -> Attributes {
      var copy = self
      copy.fontSize = size
      return copy
    }

    /// The value for NSAttributedStringKey.color. If nil, this attribute will not
    /// be present.
    public var color: UIColor?

    /// If true, create a tab stop and appropriate indentation for the "hanging indent" of a list.
    public var listLevel = 0

    public func incrementingListLevel() -> Attributes {
      var copy = self
      copy.listLevel += 1
      return copy
    }

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
      var traits = UIFontDescriptor.SymbolicTraits()
      if italic {
        traits.formUnion(.traitItalic)
      }
      if bold {
        traits.formUnion(.traitBold)
      }
      if let descriptor = UIFontDescriptor(name: familyName, size: fontSize)
        .withSymbolicTraits(traits) {
        result[.font] = UIFont(descriptor: descriptor, size: 0)
      }
      if listLevel > 0 {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 16 * CGFloat(listLevel)
        paragraphStyle.firstLineHeadIndent = 16 * CGFloat(listLevel - 1)
        let listTab = NSTextTab(
          textAlignment: .natural,
          location: paragraphStyle.headIndent,
          options: [:]
        )
        paragraphStyle.tabStops = [listTab]
        result[.paragraphStyle] = paragraphStyle
      }
      return result
    }
  }
}
