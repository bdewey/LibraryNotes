// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import FlashcardKit
import MaterialComponents.MaterialAppBar
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
    let navigationController = MDCAppBarNavigationController()
    navigationController.delegate = self
    navigationController.pushViewController(DocumentListViewController(), animated: false)
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

extension AppDelegate: MDCAppBarNavigationControllerDelegate {
  func appBarNavigationController(
    _ navigationController: MDCAppBarNavigationController,
    willAdd appBar: MDCAppBar,
    asChildOf viewController: UIViewController
  ) {
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.default.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.default.typographyScheme, to: appBar)
    if var forwarder = viewController as? MDCScrollEventForwarder {
      forwarder.headerView = appBar.headerViewController.headerView
      appBar.headerViewController.headerView.observesTrackingScrollViewScrollEvents = false
      appBar.headerViewController.headerView.shiftBehavior = forwarder.desiredShiftBehavior
    }
  }
}
