// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MaterialComponents.MDCSemanticColorScheme
import MaterialComponents.MDCTypographyScheme

extension UIColor {
  public convenience init(rgb: UInt32, alpha: CGFloat = 1.0) {
    self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
              green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
              blue: CGFloat(rgb & 0xFF) / 255.0,
              alpha: alpha)
  }

  public var brightness: CGFloat {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    self.getRed(&red, green: &green, blue: &blue, alpha: nil)
    let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
    return brightness
  }
}

public struct Stylesheet {

  public enum Style: Hashable {
    case headline1
    case headline2
    case headline3
    case headline4
    case headline5
    case headline6
    case subtitle1
    case subtitle2
    case body1
    case body2
    case caption
    case button
    case overline
  }

  public enum AlphaStyle: Hashable {
    case darkTextHighEmphasis
    case darkTextMediumEmphasis
    case darkTextDisabled
    case lightTextHighEmphasis
    case lightTextMediumEmphasis
    case lightTextDisabled
  }

  public struct Colors {

    public init() { }

    public var primaryColor = UIColor(rgb: 0x6200EE)
    public var primaryColorVariant = UIColor(rgb: 0x3700B3)
    public var secondaryColor = UIColor(rgb: 0x03DAC6)
    public var errorColor = UIColor(rgb: 0xB00020)
    public var surfaceColor = UIColor(rgb: 0xFFFFFF)
    public var darkSurfaceColor = UIColor(rgb: 0xf5f5f5)
    public var backgroundColor = UIColor(rgb: 0xFFFFFF)
    public var onPrimaryColor = UIColor(rgb: 0xFFFFFF)
    public var onSecondaryColor = UIColor(rgb: 0x000000)
    public var onSurfaceColor = UIColor(rgb: 0x000000)
    public var onBackgroundColor = UIColor(rgb: 0x000000)

    public func withDarkerColorAsPrimary() -> Colors {
      if primaryColor.brightness < secondaryColor.brightness {
        return self
      } else {
        var copy = self
        copy.primaryColor = secondaryColor
        copy.onPrimaryColor = onSecondaryColor
        return copy
      }
    }

    public var semanticColorScheme: MDCSemanticColorScheme {
      let scheme = MDCSemanticColorScheme()
      scheme.primaryColor = primaryColor
      scheme.primaryColorVariant = primaryColorVariant
      scheme.secondaryColor = secondaryColor
      scheme.errorColor = errorColor
      scheme.surfaceColor = surfaceColor
      scheme.backgroundColor = backgroundColor
      scheme.onPrimaryColor = onPrimaryColor
      scheme.onSecondaryColor = onSecondaryColor
      scheme.onSurfaceColor = onSurfaceColor
      scheme.onBackgroundColor = onBackgroundColor
      return scheme
    }
  }

  public var colors = Colors()
  public let typographyScheme = MDCTypographyScheme(defaults: .material201804)
  public var kern: [Style: CGFloat] = [:]
  public var alpha: [AlphaStyle: CGFloat] = [
    .darkTextHighEmphasis: 0.87,
    .darkTextMediumEmphasis: 0.60,
    .darkTextDisabled: 0.38,
    .lightTextHighEmphasis: 1.0,
    .lightTextMediumEmphasis: 0.60,
    .lightTextDisabled: 0.38,
  ]

  public init() { }
}

extension Stylesheet {
  public var buttonScheme: MDCButtonScheme {
    let scheme = MDCButtonScheme()
    scheme.colorScheme = self.colors.withDarkerColorAsPrimary().semanticColorScheme
    scheme.typographyScheme = self.typographyScheme
    scheme.cornerRadius = 8
    scheme.minimumHeight = 36
    return scheme
  }
}

extension NSParagraphStyle {
  public static let leftAlign: NSParagraphStyle = {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    return paragraphStyle
  }()
}

extension MDCTypographyScheme {
  subscript(style: Stylesheet.Style) -> UIFont {
    switch style {
    case .headline1: return headline1
    case .headline2: return headline2
    case .headline3: return headline3
    case .headline4: return headline4
    case .headline5: return headline5
    case .headline6: return headline6
    case .subtitle1: return subtitle1
    case .subtitle2: return subtitle2
    case .body1: return body1
    case .body2: return body2
    case .caption: return caption
    case .button: return button
    case .overline: return overline
    }
  }
}

extension Stylesheet {
  public func attributes(
    style: Stylesheet.Style,
    emphasis: AlphaStyle = .darkTextHighEmphasis,
    paragraphStyle: NSParagraphStyle = NSParagraphStyle.leftAlign
  ) -> [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme[style],
      .kern: kern[style] ?? 1.0,
      .foregroundColor: colors.onSurfaceColor.withAlphaComponent(alpha[emphasis] ?? 1),
      .paragraphStyle: paragraphStyle,
    ]
  }
}

extension Stylesheet {

  /// Style debugging help: Prints all of the available fonts to the console.
  public static func printFontNames() {
    for family in UIFont.familyNames.sorted() {
      print(family)
      for fontName in UIFont.fontNames(forFamilyName: family) {
        print(" --> \(fontName)")
      }
    }
  }
}
