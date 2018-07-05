// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit
import CommonplaceBook

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, CommonplaceBookDelegate {

  var window: UIWindow?
  let commonplaceBook = CommonplaceBook()
  let useCloud = true

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool
  {
    commonplaceBook.delegate = self
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = DocumentListViewController(commonplaceBook: commonplaceBook)
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

