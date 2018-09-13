// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

import MaterialComponents

extension UIColor {
  public convenience init(rgb: UInt32, alpha: CGFloat = 1.0) {
    self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
              green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
              blue: CGFloat(rgb & 0xFF) / 255.0,
              alpha: alpha)
  }
}

public struct Stylesheet {
  public let appTitle: String
  public let colorScheme: MDCSemanticColorScheme
  public let darkSurface: UIColor
  public let typographyScheme: MDCTypographyScheme

  public init(
    appTitle: String,
    colorScheme: MDCSemanticColorScheme,
    darkSurface: UIColor,
    typographyScheme: MDCTypographyScheme
  ) {
    self.appTitle = appTitle
    self.colorScheme = colorScheme
    self.darkSurface = darkSurface
    self.typographyScheme = typographyScheme
  }
}

extension Stylesheet {
  public var buttonScheme: MDCButtonScheme {
    let scheme = MDCButtonScheme()
    scheme.colorScheme = self.colorScheme
    scheme.typographyScheme = self.typographyScheme
    scheme.cornerRadius = 8
    scheme.minimumHeight = 36
    return scheme
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
