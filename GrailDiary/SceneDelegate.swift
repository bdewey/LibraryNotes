// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit

@objc final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  /// The currently open database
  var database: NoteDatabase?
  /// The top-level UISplitViewController that is showing the note contents.
  var topLevelViewController: NotebookViewController?

  private enum UserDefaultKey {
    static let hasRun = "has_run_0"
    static let openedDocument = "opened_document"
  }

  static var openedDocumentBookmark: Data? {
    get {
      UserDefaults.standard.object(forKey: UserDefaultKey.openedDocument) as? Data
    }
    set {
      if let value = newValue {
        UserDefaults.standard.set(value, forKey: UserDefaultKey.openedDocument)
      } else {
        UserDefaults.standard.removeObject(forKey: UserDefaultKey.openedDocument)
      }
    }
  }

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
    self.window = window

    var didOpenSavedDocument = false
    if !Self.isUITesting, let openedDocumentBookmarkData = Self.openedDocumentBookmark {
      Logger.shared.info("Bookmark data exists for an open document")
      var isStale: Bool = false
      do {
        let url = try URL(resolvingBookmarkData: openedDocumentBookmarkData, bookmarkDataIsStale: &isStale)
        Logger.shared.info("Successfully resolved url: \(url)")
        try browser.openDocument(at: url, createWelcomeContent: false, animated: false)
        didOpenSavedDocument = true
      } catch {
        Logger.shared.error("Unexpected error opening document: \(error.localizedDescription)")
      }
    }
    if !didOpenSavedDocument {
      Logger.shared.info("Trying to open the default document")
      // TODO:
//      openDefaultDocument(from: browser)
    }
  }

  @objc func openNewFile() {
    guard let documentListViewController = window?.rootViewController else {
      return
    }
    Self.openedDocumentBookmark = nil
    documentListViewController.dismiss(animated: true, completion: nil)
  }

  @objc func makeNewNote() {
    topLevelViewController?.makeNewNote()
  }
}
