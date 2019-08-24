// Copyright © 2017-present Brian's Brain. All rights reserved.

import UIKit

@nonobjc
extension UIApplication {
  /// True if the app runs in the simulator.
  static var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }
}
