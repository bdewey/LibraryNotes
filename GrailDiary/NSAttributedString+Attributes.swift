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

import Logging
import UIKit

private let logger = Logger(label: "org.brians-brain.AttributedStringAttributes")

public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]

public extension NSAttributedString.Key {
  /// A UIColor to use when rendering a vertical bar on the leading edge of a block quote.
  static let blockquoteBorderColor = NSAttributedString.Key(rawValue: "verticalBarColor")
}

/// Convenience extensions for working with an NSAttributedString attributes dictionary.
public extension Dictionary where Key == NSAttributedString.Key, Value == Any {
  /// The font attribute.
  var font: UIFont {
    get { return (self[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body) }
    set { self[.font] = newValue }
  }

  /// Setter only: Sets a dynamic font
  var textStyle: UIFont.TextStyle? {
    get { return nil }
    set {
      if let textStyle = newValue {
        self[.font] = UIFont.preferredFont(forTextStyle: textStyle)
      } else {
        self[.font] = nil
      }
    }
  }

  /// the font family name
  var familyName: String {
    get {
      return font.familyName
    }
    set {
      font = UIFont(descriptor: font.fontDescriptor.withoutStyle().withFamily(newValue), size: 0)
    }
  }

  var fontSize: CGFloat {
    get {
      return font.pointSize
    }
    set {
      font = UIFont(descriptor: font.fontDescriptor.withSize(newValue), size: 0)
    }
  }

  /// Text foreground color.
  var color: UIColor? {
    get { return self[.foregroundColor] as? UIColor }
    set { self[.foregroundColor] = newValue }
  }

  /// Text background color.
  var backgroundColor: UIColor? {
    get { return self[.backgroundColor] as? UIColor }
    set { self[.backgroundColor] = newValue }
  }

  /// A color to use when drawing a vertical bar to the left side of block quotes
  var blockquoteBorderColor: UIColor? {
    get { return self[.blockquoteBorderColor] as? UIColor }
    set { self[.blockquoteBorderColor] = newValue }
  }

  /// Desired letter spacing.
  var kern: CGFloat {
    get { return self[.kern] as? CGFloat ?? 0 }
    set { self[.kern] = newValue }
  }

  /// Whether the font is bold.
  var bold: Bool {
    get { return containsSymbolicTrait(.traitBold) }
    set {
      if newValue {
        symbolicTraitFormUnion(.traitBold)
      } else {
        symbolicTraitSubtract(.traitBold)
      }
    }
  }

  /// Whether the font is italic.
  var italic: Bool {
    get { return containsSymbolicTrait(.traitItalic) }
    set {
      if newValue {
        symbolicTraitFormUnion(.traitItalic)
      } else {
        symbolicTraitSubtract(.traitItalic)
      }
    }
  }

  /// Tests if the font contains a given symbolic trait.
  func containsSymbolicTrait(_ symbolicTrait: UIFontDescriptor.SymbolicTraits) -> Bool {
    return font.fontDescriptor.symbolicTraits.contains(symbolicTrait)
  }

  /// Sets a symbolic trait.
  mutating func symbolicTraitFormUnion(_ symbolicTrait: UIFontDescriptor.SymbolicTraits) {
    symbolicTraits = font.fontDescriptor.symbolicTraits.union(symbolicTrait)
  }

  /// Clears a symbolic trait.
  mutating func symbolicTraitSubtract(_ symbolicTrait: UIFontDescriptor.SymbolicTraits) {
    symbolicTraits = font.fontDescriptor.symbolicTraits.subtracting(symbolicTrait)
  }

  /// The symbolic traits for the font. Can be nil if there is no font.
  /// Attempts to set the symbolic traits to nil will be ignored.
  var symbolicTraits: UIFontDescriptor.SymbolicTraits {
    get {
      return font.fontDescriptor.symbolicTraits
    }
    set {
      guard let descriptor = font.fontDescriptor.withSymbolicTraits(newValue)
      else {
        logger.error("Unable to set \(String(describing: newValue)) on font: \(String(describing: font))")
        return
      }
      font = UIFont(descriptor: descriptor, size: 0)
    }
  }

  var paragraphStyle: NSParagraphStyle? {
    get { return self[.paragraphStyle] as? NSParagraphStyle }
    set { self[.paragraphStyle] = newValue }
  }

  private var mutableParagraphStyle: NSMutableParagraphStyle {
    if let paragraphStyle = paragraphStyle {
      // swiftlint:disable:next force_cast
      return paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
    } else {
      return NSMutableParagraphStyle()
    }
  }

  var headIndent: CGFloat {
    get { return paragraphStyle?.headIndent ?? 0 }
    set {
      let style = mutableParagraphStyle
      style.headIndent = newValue
      paragraphStyle = style
    }
  }

  var tailIndent: CGFloat {
    get { return paragraphStyle?.tailIndent ?? 0 }
    set {
      let style = mutableParagraphStyle
      style.tailIndent = newValue
      paragraphStyle = style
    }
  }

  var firstLineHeadIndent: CGFloat {
    get { return paragraphStyle?.firstLineHeadIndent ?? 0 }
    set {
      let style = mutableParagraphStyle
      style.firstLineHeadIndent = newValue
      paragraphStyle = style
    }
  }

  var alignment: NSTextAlignment {
    get { return paragraphStyle?.alignment ?? NSParagraphStyle.default.alignment }
    set {
      let style = mutableParagraphStyle
      style.alignment = newValue
      paragraphStyle = style
    }
  }

  var lineHeightMultiple: CGFloat {
    get { return paragraphStyle?.lineHeightMultiple ?? 0 }
    set {
      let style = mutableParagraphStyle
      style.lineHeightMultiple = newValue
      paragraphStyle = style
    }
  }

  var listLevel: Int {
    get { return self[.listLevel] as? Int ?? 0 }
    set {
      self[.listLevel] = newValue
      let indentAmountPerLevel: CGFloat = headIndent > 0 ? headIndent : 16
      let listStyling = mutableParagraphStyle
      if listLevel > 0 {
        listStyling.headIndent = indentAmountPerLevel * CGFloat(listLevel)
        listStyling.firstLineHeadIndent = indentAmountPerLevel * CGFloat(listLevel - 1)
        var tabStops: [NSTextTab] = []
        for i in 0 ..< 4 {
          let listTab = NSTextTab(
            textAlignment: .natural,
            location: listStyling.headIndent + CGFloat(i) * indentAmountPerLevel,
            options: [:]
          )
          tabStops.append(listTab)
        }
        listStyling.tabStops = tabStops
      } else {
        listStyling.headIndent = 0
        listStyling.firstLineHeadIndent = 0
        listStyling.tabStops = []
      }
      paragraphStyle = listStyling
    }
  }
}

private extension UIFontDescriptor {
  /// Returns a copy of the receiver without any .textStyle attribute.
  /// .textStyle takes precedence over familyName, so you need to remove the attribute if you want to customize the family.
  func withoutStyle() -> UIFontDescriptor {
    var attributes = fontAttributes
    attributes.removeValue(forKey: .textStyle)
    return UIFontDescriptor(fontAttributes: attributes)
  }
}

private extension NSAttributedString.Key {
  static let listLevel = NSAttributedString.Key(rawValue: "org.brians-brain.list-level")
}

public extension UIFont {
  var attributesDictionary: [NSAttributedString.Key: Any] {
    var attributes = [NSAttributedString.Key: Any]()
    attributes.font = self
    attributes.lineHeightMultiple = 1.2
    return attributes
  }
}
