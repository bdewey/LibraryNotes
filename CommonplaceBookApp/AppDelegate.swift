// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  let useCloud = true

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console

    let window = UIWindow(frame: UIScreen.main.bounds)
    let navigationController = UINavigationController(
      rootViewController: DocumentListViewController()
    )
    navigationController.isNavigationBarHidden = true
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}
