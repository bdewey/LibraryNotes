// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit
import UniformTypeIdentifiers

public extension UTType {
  static let kvcrdt = UTType("org.brians-brain.kvcrdt")!
  static let libnotes = UTType("org.brians-brain.libnotes")!
}

private extension Logger {
  static let sceneDelegate: Logger = {
    var logger = Logger(label: "org.brians-brain.LibraryNotes.SceneDelegate")
    logger.logLevel = .trace
    return logger
  }()
}

/// The activities that this app knows how to handle.
enum LibraryNotesActivityType: String {
  /// Open a specific library
  case openLibrary = "org.brians-brain.LibraryNotes.OpenLibrary"

  /// Start a new study session.
  case studySession = "org.brians-brain.LibraryNotes.StudySession"
}

extension NSUserActivity {
  private enum UserInfoKey {
    static let documentURL = "org.brians-brain.GrailDiary.OpenNotebook.URL"
    static let focusStructure = "org.brians-brain.LibraryNotes.FocusStructure"
  }

  /// Creates an ``NSUserActivity`` for opening the library at ``url``.
  static func openLibrary(at url: URL) throws -> NSUserActivity {
    let urlData = try url.bookmarkData()
    let activity = NSUserActivity(activityType: LibraryNotesActivityType.openLibrary.rawValue)
    activity.title = "Open Library"
    activity.addUserInfoEntries(from: [UserInfoKey.documentURL: urlData])
    return activity
  }

  /// Gets the URL of the library to open.
  var libraryURL: URL {
    get throws {
      guard let urlData = userInfo?[UserInfoKey.documentURL] as? Data else {
        throw GenericLocalizedError(errorDescription: "Activity does not have \(UserInfoKey.documentURL)")
      }
      var isStale = false
      return try URL(resolvingBookmarkData: urlData, bookmarkDataIsStale: &isStale)
    }
  }

  var focusStructure: NotebookStructureViewController.StructureIdentifier {
    get throws {
      guard
        let rawValue = userInfo?[UserInfoKey.focusStructure] as? String,
        let focusStructure = NotebookStructureViewController.StructureIdentifier(rawValue: rawValue)
      else {
        throw GenericLocalizedError(errorDescription: "Could not get focusStructure from activity")
      }
      return focusStructure
    }
  }

  static func studySession(databaseURL: URL, focusStructure: NotebookStructureViewController.StructureIdentifier) throws -> NSUserActivity {
    let activity = NSUserActivity(activityType: LibraryNotesActivityType.studySession.rawValue)
    activity.requiredUserInfoKeys = [UserInfoKey.documentURL, UserInfoKey.focusStructure]
    let bookmarkData = try databaseURL.bookmarkData()
    activity.addUserInfoEntries(from: [
      UserInfoKey.documentURL: bookmarkData,
      UserInfoKey.focusStructure: focusStructure.rawValue,
    ])
    return activity
  }
}

@objc final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  var studyWindow: UIWindow?

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
    Logger.sceneDelegate.info("\(#function) Connecting a new scene to a scene session (self = \(ObjectIdentifier(self))")
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    var isConfigured = false

    if let stateRestorationActivity = session.stateRestorationActivity {
      isConfigured = isConfigured || configureWindow(window, userActivity: stateRestorationActivity)
    }
    for userActivity in connectionOptions.userActivities {
      isConfigured = isConfigured || configureWindow(window, userActivity: userActivity)
    }

    if !isConfigured {
      let browser = DocumentBrowserViewController(forOpening: [.kvcrdt, .libnotes])
      window.rootViewController = browser
    }
    window.makeKeyAndVisible()
    self.window = window
  }

  func configureWindow(_ window: UIWindow, userActivity: NSUserActivity) -> Bool {
    guard let activityType = LibraryNotesActivityType(rawValue: userActivity.activityType) else {
      Logger.sceneDelegate.error("Unexpected activity type: \(userActivity.activityType)")
      return false
    }
    switch activityType {
    case .openLibrary:
      return configureLibraryWindow(window, userActivity: userActivity)
    case .studySession:
      return configureStudySessionWindow(window, userActivity: userActivity)
    }
  }

  func configureLibraryWindow(_ window: UIWindow, userActivity: NSUserActivity) -> Bool {
    guard let url = try? userActivity.libraryURL else {
      return false
    }
    Logger.sceneDelegate.info("Opening document at \"\(url.path)\"")
#if targetEnvironment(macCatalyst)
    window.windowScene?.title = url.deletingPathExtension().lastPathComponent
    window.windowScene?.titlebar?.representedURL = url
#endif
    Task {
      let database: NoteDatabase
      if url.pathExtension == UTType.libnotes.preferredFilenameExtension || url.pathExtension == "kvcrdt" {
        database = try await NoteDatabase(fileURL: url, authorDescription: UIDevice.current.name)
      } else {
        throw CocoaError(CocoaError.fileReadUnsupportedScheme)
      }
      Logger.sceneDelegate.info("Using document at \(database.fileURL)")
      let properties: [String: String] = [
        "documentState": String(describing: database.documentState),
      ]
      Logger.sceneDelegate.info("In open completion handler. \(properties)")
      let viewController = NotebookViewController(database: database)
      viewController.modalPresentationStyle = .fullScreen
      viewController.modalTransitionStyle = .crossDissolve
      viewController.view.tintColor = .systemOrange
      window.rootViewController = viewController
    }
    return true
  }

  func configureStudySessionWindow(_ window: UIWindow, userActivity: NSUserActivity) -> Bool {
    guard let databaseURL = try? userActivity.libraryURL, let structureIdentifier = try? userActivity.focusStructure else {
      return false
    }
    window.windowScene?.title = "Review \(databaseURL.deletingPathExtension().lastPathComponent)"
    Task {
      let database = try await NoteDatabase(fileURL: databaseURL, authorDescription: UIDevice.current.name)
      for try await noteIdentifierRecords in database.noteIdentifiersPublisher(structureIdentifier: structureIdentifier, sortOrder: .creationTimestamp, groupByYearRead: false, searchTerm: nil).values {
        let noteIdentifiers = noteIdentifierRecords.map({ $0.noteIdentifier })
        let studySession = try database.studySession(noteIdentifiers: Set(noteIdentifiers), date: .now).shuffling().ensuringUniquePromptCollections().limiting(to: 20)
        let studyViewController = StudyViewController(studySession: studySession, database: database, delegate: self)
        studyViewController.view.backgroundColor = .grailBackground
        window.rootViewController = studyViewController
        self.studyWindow = window
        return
      }
    }
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let urlContext = URLContexts.first else {
      Logger.sceneDelegate.warning("\(#function) Nothing to open")
      return
    }
    do {
      let activity = try NSUserActivity.openLibrary(at: urlContext.url)
      Logger.sceneDelegate.info("\(#function) Creating new scene to open \(urlContext.url)")
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
    } catch {
      Logger.sceneDelegate.error("\(#function): Error creating openLibrary activity: \(error)")
    }
  }

  private func configureWindowScene(_ windowScene: UIWindowScene, browserConfigurationBlock: @escaping (DocumentBrowserViewController) async throws -> Void) {
    let window = UIWindow(windowScene: windowScene)
    let browser = DocumentBrowserViewController(forOpening: [.kvcrdt, .libnotes])

    window.rootViewController = browser
    window.makeKeyAndVisible()

    Task {
      do {
        try await browserConfigurationBlock(browser)
      } catch {
        Logger.sceneDelegate.error("\(#function) Error configuring browser: \(error)")
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
        Logger.sceneDelegate.error("Unexpected error creating starter library: \(error)")
      }
    }
    return nil
  }

  func sceneWillResignActive(_ scene: UIScene) {
    guard let browser = window?.rootViewController as? DocumentBrowserViewController else {
      return
    }
    Logger.sceneDelegate.info("Saving user activity for sceneWillResignActive")
    scene.userActivity = browser.makeUserActivity()
  }

  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    return scene.userActivity
  }
}

extension SceneDelegate: StudyViewControllerDelegate {
  func studyViewController(_ studyViewController: StudyViewController, didFinishSession studySession: StudySession) {
    guard let session = studyViewController.responderChainWindowScene?.session else { return }
    try? studyViewController.database.updateStudySessionResults(studySession, on: .now, buryRelatedPrompts: true)
    UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
  }
}

#if targetEnvironment(macCatalyst)
final class ToolbarDelegate: NSObject, NSToolbarDelegate {
  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    Logger.sceneDelegate.trace("\(#function)")
    return [.toggleSidebar]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    Logger.sceneDelegate.trace("\(#function)")
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
