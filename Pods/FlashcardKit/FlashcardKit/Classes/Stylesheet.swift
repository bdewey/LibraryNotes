// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MaterialComponents
import NunitoSans

extension Stylesheet {
  @available(*, deprecated)
  public static let hablaEspanol: Stylesheet = {
    let colorScheme = MDCSemanticColorScheme()
    colorScheme.surfaceColor = UIColor.white
    colorScheme.primaryColor = UIColor(rgb: 0x5D1049)
    colorScheme.secondaryColor = UIColor(rgb: 0xFA3336)
    let typographyScheme = MDCTypographyScheme()
    NunitoSans.loadAllFonts()
    typographyScheme.headline6 = UIFont.nunitoSansSemiBold(size: 21.65)
    typographyScheme.body2 = UIFont.nunitoSansRegular(size: 15.19)
    typographyScheme.button = UIFont.nunitoSansSemiBold(size: 15.16)
    typographyScheme.overline = UIFont.nunitoSansSemiBold(size: 12.99)
    typographyScheme.caption = UIFont.nunitoSansSemiBold(size: 12.99)
    return Stylesheet(
      appTitle: "¡Habla Español!",
      colorScheme: colorScheme,
      darkSurface: UIColor(rgb: 0xf5f5f5),
      typographyScheme: typographyScheme
    )
  }()
}
