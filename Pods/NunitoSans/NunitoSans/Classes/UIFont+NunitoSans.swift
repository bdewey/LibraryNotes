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

import Foundation

public enum NunitoSans {
  public static let black = "NunitoSans-Black"
  public static let blackItalic = "NunitoSans-BlackItalic"
  public static let regular = "NunitoSans-Regular"
  public static let semiBold = "NunitoSans-SemiBold"
}

extension UIFont {
  public static func nunitoSansBlack(size: CGFloat) -> UIFont {
    loadNunitoSansBlack
    return UIFont(name: NunitoSans.black, size: size)!
  }

  public static func nunitoSansBlackItalic(size: CGFloat) -> UIFont {
    loadNunitoSansBlackItalic
    return UIFont(name: NunitoSans.blackItalic, size: size)!
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

// swiftlint:disable:next convenience_type
private final class FontLoader {
  static func loadFont(named name: String) {
    let bundle = Bundle(for: FontLoader.self)
    let resourceURL = bundle.url(forResource: "NunitoSans", withExtension: "bundle")!
    let resourceBundle = Bundle(url: resourceURL)!
    let fontURL = resourceBundle.url(forResource: name, withExtension: "ttf")!
    let data = try! Data(contentsOf: fontURL) // swiftlint:disable:this force_try
    let dataProvider = CGDataProvider(data: data as CFData)!
    let font = CGFont(dataProvider)!
    CTFontManagerRegisterGraphicsFont(font, nil)
  }
}

private let loadNunitoSansBlack: Void = {
  FontLoader.loadFont(named: NunitoSans.black)
}()

private let loadNunitoSansBlackItalic: Void = {
  FontLoader.loadFont(named: NunitoSans.blackItalic)
}()

private let loadNunitoSansRegular: Void = {
  FontLoader.loadFont(named: NunitoSans.regular)
}()

private let loadNunitoSansSemiBold: Void = {
  FontLoader.loadFont(named: NunitoSans.semiBold)
}()
