// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import Foundation
import MaterialComponents
import NunitoSans

extension Stylesheet {
  @available(*, deprecated)
  public static let hablaEspanol: Stylesheet = {
    var stylesheet = Stylesheet()
    stylesheet.colorScheme.surfaceColor = UIColor.white
    stylesheet.colorScheme.primaryColor = UIColor(rgb: 0x5D1049)
    stylesheet.colorScheme.secondaryColor = UIColor(rgb: 0xFA3336)
    NunitoSans.loadAllFonts()
    stylesheet.typographyScheme.headline6 = UIFont.nunitoSansSemiBold(size: 21.65)
    stylesheet.typographyScheme.body2 = UIFont.nunitoSansRegular(size: 15.19)
    stylesheet.typographyScheme.button = UIFont.nunitoSansSemiBold(size: 15.16)
    stylesheet.typographyScheme.overline = UIFont.nunitoSansSemiBold(size: 12.99)
    stylesheet.typographyScheme.caption = UIFont.nunitoSansSemiBold(size: 12.99)
    return stylesheet
  }()
}
