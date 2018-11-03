// Copyright © 2018 Brian's Brain. All rights reserved.

import MaterialComponents.MDCShadowLayer
import UIKit

/// A view with a shadow.
open class ShadowView: UIView {
  override open class var layerClass: AnyClass {
    return MDCShadowLayer.self
  }

  open var shadowLayer: MDCShadowLayer {
    return self.layer as! MDCShadowLayer // swiftlint:disable:this force_cast
  }

  open var shadowElevation: ShadowElevation {
    get {
      return shadowLayer.elevation
    }
    set {
      shadowLayer.elevation = newValue
    }
  }
}
