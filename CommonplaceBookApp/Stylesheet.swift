//
//  Stylesheet.swift
//  remember
//
//  Created by Brian Dewey on 5/1/18.
//  Copyright © 2018 Brian's Brain. All rights reserved.
//

import Foundation

import MaterialComponents

fileprivate func printFontNames() {
  for family in UIFont.familyNames.sorted() {
    print(family)
    for fontName in UIFont.fontNames(forFamilyName: family) {
      print(" --> \(fontName)")
    }
  }
}

struct Stylesheet
{
  let colorScheme: MDCSemanticColorScheme
  let typographyScheme: MDCTypographyScheme
  
  static let `default`: Stylesheet = {
    let colorScheme = MDCSemanticColorScheme()
    colorScheme.primaryColor = UIColor.white
    colorScheme.onPrimaryColor = UIColor.black
    colorScheme.secondaryColor = UIColor(rgb: 0x661FFF)
    colorScheme.surfaceColor = UIColor.white
    let typographyScheme = MDCTypographyScheme()
    printFontNames()
    typographyScheme.headline6 = UIFont(name: "LibreFranklin-Medium", size: 20.0)!
    typographyScheme.body2 = UIFont(name: "LibreFranklin-Regular", size: 14.0)!
    return Stylesheet(colorScheme: colorScheme, typographyScheme: typographyScheme)
  }()
}
