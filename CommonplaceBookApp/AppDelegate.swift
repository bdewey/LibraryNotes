// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool
  {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = TextEditViewController()
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

