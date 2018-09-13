// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MaterialComponents

extension Stylesheet {
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
    return Stylesheet(
      appTitle: "Commonplace Book",
      colorScheme: colorScheme,
      darkSurface: UIColor(rgb: 0xf5f5f5),
      typographyScheme: typographyScheme
    )
  }()
}
