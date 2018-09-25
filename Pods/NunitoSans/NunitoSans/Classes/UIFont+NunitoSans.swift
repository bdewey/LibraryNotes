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

// swiftlint:disable:next convenience_type
private final class FontLoader {
  static func loadFont(named name: String) {
    let bundle = Bundle(for: FontLoader.self)
    let resourceURL = bundle.url(forResource: "NunitoSans", withExtension: "bundle")!
    let resourceBundle = Bundle(url: resourceURL)!
    let fontURL = resourceBundle.url(forResource: name, withExtension: "ttf")!
    CTFontManagerRegisterFontsForURL(fontURL as CFURL, CTFontManagerScope.process, nil)
  }
}

public enum NunitoSans {
  public static let black = "NunitoSans-Black"
  public static let blackItalic = "NunitoSans-BlackItalic"
  public static let bold = "NunitoSans-Bold"
  public static let boldItalic = "NunitoSans-BoldItalic"
  public static let extraBold = "NunitoSans-ExtraBold"
  public static let extraBoldItalic = "NunitoSans-ExtraBoldItalic"
  public static let extraLight = "NunitoSans-ExtraLight"
  public static let italic = "NunitoSans-Italic"
  public static let regular = "NunitoSans-Regular"
  public static let semiBold = "NunitoSans-SemiBold"

  public static func loadAllFonts() {
    loadNunitoSansBlack
    loadNunitoSansBlackItalic
    loadNunitoSansBold
    loadNunitoSansBoldItalic
    loadNunitoSansExtraBold
    loadNunitoSansExtraBoldItalic
    loadNunitoSansExtraLight
    loadNunitoSansItalic
    loadNunitoSansRegular
    loadNunitoSansSemiBold
  }
}

private let loadNunitoSansBlack: Void = {
  FontLoader.loadFont(named: NunitoSans.black)
}()

private let loadNunitoSansBlackItalic: Void = {
  FontLoader.loadFont(named: NunitoSans.blackItalic)
}()

private let loadNunitoSansBold: Void = {
  FontLoader.loadFont(named: NunitoSans.bold)
}()

private let loadNunitoSansBoldItalic: Void = {
  FontLoader.loadFont(named: NunitoSans.boldItalic)
}()

private let loadNunitoSansExtraBold: Void = {
  FontLoader.loadFont(named: NunitoSans.extraBold)
}()

private let loadNunitoSansExtraBoldItalic: Void = {
  FontLoader.loadFont(named: NunitoSans.extraBoldItalic)
}()

private let loadNunitoSansExtraLight: Void = {
  FontLoader.loadFont(named: NunitoSans.extraLight)
}()

private let loadNunitoSansItalic: Void = {
  FontLoader.loadFont(named: NunitoSans.italic)
}()

private let loadNunitoSansRegular: Void = {
  FontLoader.loadFont(named: NunitoSans.regular)
}()

private let loadNunitoSansSemiBold: Void = {
  FontLoader.loadFont(named: NunitoSans.semiBold)
}()

extension UIFont {
  public static func nunitoSansBlack(size: CGFloat) -> UIFont {
    loadNunitoSansBlack
    return UIFont(name: NunitoSans.black, size: size)!
  }

  public static func nunitoSansBlackItalic(size: CGFloat) -> UIFont {
    loadNunitoSansBlackItalic
    return UIFont(name: NunitoSans.blackItalic, size: size)!
  }

  public static func nunitoSansBold(size: CGFloat) -> UIFont {
    loadNunitoSansBold
    return UIFont(name: NunitoSans.bold, size: size)!
  }

  public static func nunitoSansBoldItalic(size: CGFloat) -> UIFont {
    loadNunitoSansBoldItalic
    return UIFont(name: NunitoSans.boldItalic, size: size)!
  }

  public static func nunitoSansExtraBold(size: CGFloat) -> UIFont {
    loadNunitoSansExtraBold
    return UIFont(name: NunitoSans.extraBold, size: size)!
  }

  public static func nunitoSansExtraBoldItalic(size: CGFloat) -> UIFont {
    loadNunitoSansExtraBoldItalic
    return UIFont(name: NunitoSans.extraBoldItalic, size: size)!
  }

  public static func nunitoSansExtraLight(size: CGFloat) -> UIFont {
    loadNunitoSansExtraLight
    return UIFont(name: NunitoSans.extraLight, size: size)!
  }

  public static func nunitoSansItalic(size: CGFloat) -> UIFont {
    loadNunitoSansItalic
    return UIFont(name: NunitoSans.italic, size: size)!
  }

  public static func nunitoSansRegular(size: CGFloat) -> UIFont {
    loadNunitoSansRegular
    return UIFont(name: NunitoSans.regular, size: size)!
  }

  public static func nunitoSansSemiBold(size: CGFloat) -> UIFont {
    loadNunitoSansSemiBold
    return UIFont(name: NunitoSans.semiBold, size: size)!
  }
}
