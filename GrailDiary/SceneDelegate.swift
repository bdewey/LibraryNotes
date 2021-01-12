// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit

@objc final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  /// The currently open database
  var database: NoteDatabase?
  /// The top-level UISplitViewController that is showing the note contents.
  var topLevelViewController: NotebookViewController?

  static var isUITesting: Bool = {
    CommandLine.arguments.contains("--uitesting")
  }()

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Logger.shared.info("Connecting a new scene to a scene session (self = \(ObjectIdentifier(self))")
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)

    let browser = DocumentBrowserViewController(forOpening: [.grailDiary, .plainText])

    window.rootViewController = browser
    window.makeKeyAndVisible()

    if let userActivity = connectionOptions.userActivities.first ?? scene.session.stateRestorationActivity {
      browser.configure(with: userActivity)
    }
    self.window = window
  }

  func sceneWillResignActive(_ scene: UIScene) {
    guard let browser = window?.rootViewController as? DocumentBrowserViewController else {
      return
    }
    Logger.shared.info("Saving user activity for sceneWillResignActive")
    scene.userActivity = browser.makeUserActivity()
  }

  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    return scene.userActivity
  }
}
