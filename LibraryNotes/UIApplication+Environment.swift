// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import os
import StoreKit
import UIKit

@nonobjc
extension UIApplication {
  /// True if the app runs in the simulator.
  nonisolated static var isSimulator: Bool {
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

  @available(iOS 18.0, *)
  static func isTestFlightAsync() async -> Bool {
    do {
      let verificationResult = try await AppTransaction.shared
      switch verificationResult {
      case .verified(let appTransaction):
        return appTransaction.environment == .sandbox
      case .unverified:
        return false
      }
    } catch {
      Logger.shared.error("Error validating app receipt: \(error)")
      return false
    }
  }
}
