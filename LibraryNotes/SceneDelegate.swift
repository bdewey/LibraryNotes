// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit
import UniformTypeIdentifiers

public extension UTType {
  static let kvcrdt = UTType("org.brians-brain.kvcrdt")!
  static let libnotes = UTType("org.brians-brain.libnotes")!
}

@objc final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  /// The currently open database
  var database: NoteDatabase?
  /// The top-level UISplitViewController that is showing the note contents.
  var topLevelViewController: NotebookViewController?

  #if targetEnvironment(macCatalyst)
  let toolbarDelegate = ToolbarDelegate()
  #endif

  static var isUITesting: Bool = {
    CommandLine.arguments.contains("--uitesting")
  }()

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    Logger.shared.info("\(#function) Connecting a new scene to a scene session (self = \(ObjectIdentifier(self))")
    guard let windowScene = scene as? UIWindowScene else { return }
    configureWindowScene(windowScene) { browser in
      if !Self.isUITesting,
         let userActivity = connectionOptions.userActivities.first ?? scene.session.stateRestorationActivity
      {
        browser.configure(with: userActivity)
      } else if let firstLaunchURL = self.firstLaunchURL {
        try await browser.openDocument(at: firstLaunchURL, animated: false)
      }
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let urlContext = URLContexts.first else {
      Logger.shared.warning("\(#function) Nothing to open")
      return
    }
    do {
      let activity = try NSUserActivity.openLibrary(at: urlContext.url)
      Logger.shared.info("\(#function) Creating new scene to open \(urlContext.url)")
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
    } catch {
      Logger.shared.error("\(#function): Error creating openLibrary activity: \(error)")
    }
  }

  private func configureWindowScene(_ windowScene: UIWindowScene, browserConfigurationBlock: @escaping (DocumentBrowserViewController) async throws -> Void) {
    let window = UIWindow(windowScene: windowScene)
    //    windowScene.titlebar?.titleVisibility = .hidden
    //    windowScene.titlebar?.toolbar = nil
    //    windowScene.titlebar?.separatorStyle = .none
#if targetEnvironment(macCatalyst)
    let toolbar = NSToolbar(identifier: "main")
    toolbar.delegate = toolbarDelegate
    toolbar.displayMode = .iconOnly
    windowScene.titlebar?.toolbar = toolbar
#endif

    let browser = DocumentBrowserViewController(forOpening: [.kvcrdt, .libnotes])

    window.rootViewController = browser
    window.makeKeyAndVisible()

    Task {
      do {
        try await browserConfigurationBlock(browser)
      } catch {
        Logger.shared.error("\(#function) Error configuring browser: \(error)")
      }
      self.window = window
      UITableView.appearance().backgroundColor = .grailGroupedBackground
    }
  }

  /// A URL to open on the launch of the app.
  private var firstLaunchURL: URL? {
    if Self.isUITesting {
      return FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(UTType.libnotes.preferredFilenameExtension ?? "kvcrdt")
    }
    if !UserDefaults.standard.hasRunBefore, let starterLibrary = Bundle.main.url(forResource: "library", withExtension: "libnotes") {
      UserDefaults.standard.hasRunBefore = true
      do {
        let documentsDirectoryURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let destinationURL = documentsDirectoryURL.appendingPathComponent(starterLibrary.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          return destinationURL
        }
        try FileManager.default.copyItem(at: starterLibrary, to: destinationURL)
        return destinationURL
      } catch {
        Logger.shared.error("Unexpected error creating starter library: \(error)")
      }
    }
    return nil
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

#if targetEnvironment(macCatalyst)
final class ToolbarDelegate: NSObject, NSToolbarDelegate {
  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    Logger.shared.trace("\(#function)")
    return [.toggleSidebar]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    Logger.shared.trace("\(#function)")
    return toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    return nil
  }
}
#endif
