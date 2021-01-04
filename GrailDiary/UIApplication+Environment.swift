// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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

  static var versionString: String {
    let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
    let shortVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")

    return "\(shortVersionString ?? "nil") (\(shortVersionNumber ?? -1))"
  }
}
