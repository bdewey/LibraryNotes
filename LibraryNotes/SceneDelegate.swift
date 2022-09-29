// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Algorithms
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

  /// Show random quotes
  case showRandomQuotes = "org.brians-brain.LibraryNotes.RandomQuotes"
}

extension NSUserActivity {
  private enum UserInfoKey {
    static let documentURL = "org.brians-brain.GrailDiary.OpenNotebook.URL"
    static let focusStructure = "org.brians-brain.LibraryNotes.FocusStructure"
    static let quoteIdentifiers = "org.brians-brain.LibraryNotes.QuoteIdentifiers"
  }

  /// A "thing" that can be studied in a notebook.
  enum StudyTarget {
    /// An entire section of a notebook.
    case focusStructure(NotebookStructureViewController.StructureIdentifier)

    /// A single note in a notebook.
    case note(Note.Identifier)

    init?(rawValue: String) {
      if let focusStructureString = rawValue.suffixIfHasPrefix("focus-structure:"), let focusStructure = NotebookStructureViewController.StructureIdentifier(rawValue: focusStructureString) {
        self = .focusStructure(focusStructure)
      } else if let noteIdentifier = rawValue.suffixIfHasPrefix("note-identifier:") {
        self = .note(noteIdentifier)
      } else {
        return nil
      }
    }

    var rawValue: String {
      switch self {
      case .note(let identifier):
        return "note-identifier:\(identifier)"
      case .focusStructure(let identifier):
        return "focus-structure:\(identifier.rawValue)"
      }
    }
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

  var quoteIdentifiers: [ContentIdentifier] {
    get throws {
      guard
        let data = userInfo?[UserInfoKey.quoteIdentifiers] as? Data,
        let identifiers = try? JSONDecoder().decode([ContentIdentifier].self, from: data)
      else {
        throw GenericLocalizedError(errorDescription: "Activity does not have \(UserInfoKey.quoteIdentifiers)")
      }
      return identifiers
    }
  }

  /// The "thing" this activity says we should study.
  var studyTarget: StudyTarget {
    get throws {
      guard
        let rawValue = userInfo?[UserInfoKey.focusStructure] as? String,
        let studyTarget = StudyTarget(rawValue: rawValue)
      else {
        throw GenericLocalizedError(errorDescription: "Could not get focusStructure from activity")
      }
      return studyTarget
    }
  }

  /// Constructs an `NSUserActivity` for studying a target in a database.
  static func studySession(databaseURL: URL, studyTarget: StudyTarget) throws -> NSUserActivity {
    let activity = NSUserActivity(activityType: LibraryNotesActivityType.studySession.rawValue)
    activity.requiredUserInfoKeys = [UserInfoKey.documentURL, UserInfoKey.focusStructure]
    let bookmarkData = try databaseURL.bookmarkData()
    activity.addUserInfoEntries(from: [
      UserInfoKey.documentURL: bookmarkData,
      UserInfoKey.focusStructure: studyTarget.rawValue,
    ])
    return activity
  }

  static func showRandomQuotes(databaseURL: URL, quoteIdentifiers: [ContentIdentifier]) throws -> NSUserActivity {
    let activity = NSUserActivity(activityType: LibraryNotesActivityType.showRandomQuotes.rawValue)
    activity.requiredUserInfoKeys = [UserInfoKey.documentURL, UserInfoKey.quoteIdentifiers]
    let bookmarkData = try databaseURL.bookmarkData()
    let identifierData = try JSONEncoder().encode(quoteIdentifiers)
    activity.addUserInfoEntries(from: [
      UserInfoKey.documentURL: bookmarkData,
      UserInfoKey.quoteIdentifiers: identifierData,
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

  static var isUITesting: Bool = CommandLine.arguments.contains("--uitesting")

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
      Logger.sceneDelegate.trace("Attempting to restore state activity: \(stateRestorationActivity.activityType)")
      isConfigured = isConfigured || configureWindow(window, userActivity: stateRestorationActivity)
    }
    for userActivity in connectionOptions.userActivities {
      Logger.sceneDelegate.trace("Will consider connectionOptions.userActivity \(userActivity.activityType), isConfigured = \(isConfigured)")
      isConfigured = isConfigured || configureWindow(window, userActivity: userActivity)
      Logger.sceneDelegate.trace("Did consider connectionOptions.userActivity \(userActivity.activityType), isConfigured = \(isConfigured)")
    }

    if !isConfigured {
      Logger.sceneDelegate.trace("Window has not yet been configured; creating document browser")
      let browser = DocumentBrowserViewController(forOpening: [.kvcrdt, .libnotes])
      window.rootViewController = browser
    }

    #if targetEnvironment(macCatalyst)
      let toolbar = NSToolbar(identifier: "main")
      toolbar.displayMode = .iconOnly
      toolbar.delegate = toolbarDelegate
      toolbar.allowsUserCustomization = true
      windowScene.titlebar?.toolbar = toolbar
    #endif
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
    case .showRandomQuotes:
      return configureQuotesWindow(window, userActivity: userActivity)
    }
  }

  func configureQuotesWindow(_ window: UIWindow, userActivity: NSUserActivity) -> Bool {
    guard let url = try? userActivity.libraryURL else {
      return false
    }
    Logger.sceneDelegate.info("Showing random quotes from \"\(url.path)\"")
    #if targetEnvironment(macCatalyst)
      window.windowScene?.title = "Random Quotes"
    #endif
    Task {
      let database = try await NoteDatabase(fileURL: url, authorDescription: UIDevice.current.name)
      let quotesViewController = QuotesViewController(database: database)
      quotesViewController.quoteIdentifiers = try userActivity.quoteIdentifiers
      window.rootViewController = UINavigationController(rootViewController: quotesViewController)
    }
    return true
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
    guard let databaseURL = try? userActivity.libraryURL, let studyTarget = try? userActivity.studyTarget else {
      return false
    }
    window.windowScene?.title = "Review \(databaseURL.deletingPathExtension().lastPathComponent)"
    if let sizeRestrictions = window.windowScene?.sizeRestrictions {
      sizeRestrictions.minimumSize = CGSize(width: 500, height: 400)
      sizeRestrictions.maximumSize = CGSize(width: 500, height: 400)
      if #available(macCatalyst 16.0, *) {
        sizeRestrictions.allowsFullScreen = false
      }
    }
    Task {
      let database = try await NoteDatabase(fileURL: databaseURL, authorDescription: UIDevice.current.name)
      var noteIdentifiers: [Note.Identifier]?
      switch studyTarget {
      case .note(let identifier):
        noteIdentifiers = [identifier]
      case .focusStructure(let structureIdentifier):
        for try await noteIdentifierRecords in database.noteIdentifiersPublisher(structureIdentifier: structureIdentifier, sortOrder: .creationTimestamp, groupByYearRead: false, searchTerm: nil).values {
          noteIdentifiers = noteIdentifierRecords.map(\.noteIdentifier)
          break
        }
      }
      guard let noteIdentifiers else { return }
      let studySession = try database.studySession(noteIdentifiers: Set(noteIdentifiers), date: .now).shuffling().ensuringUniquePromptCollections().limiting(to: 20)
      let studyViewController = StudyViewController(studySession: studySession, database: database, delegate: self)
      studyViewController.view.backgroundColor = .grailBackground
      window.rootViewController = studyViewController
      self.studyWindow = window
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
    scene.userActivity
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
  extension NSToolbarItem.Identifier {
    static let centerItemGroups = NSToolbarItem.Identifier("org.brians-brain.center-item-groups")
    static let trailingItemGroups = NSToolbarItem.Identifier("org.brians-brain.trailing-item-groups")

    func subidentifier(index: Int) -> NSToolbarItem.Identifier {
      NSToolbarItem.Identifier("\(rawValue)-\(index)")
    }

    func subIdentifierIndex(from subIdentifier: NSToolbarItem.Identifier) -> Int? {
      guard subIdentifier.rawValue.hasPrefix(rawValue) else {
        return nil
      }
      // Remove the prefix and dash
      let suffixSubstring = subIdentifier.rawValue.dropFirst(rawValue.count + 1)
      return Int(suffixSubstring)
    }
  }

  extension NSToolbarItemGroup {
    convenience init(identifier: NSToolbarItem.Identifier, barButtonGroup: UIBarButtonItemGroup) {
      let subitems = barButtonGroup.barButtonItems.enumerated().map { index, barButtonItem -> NSToolbarItem in
        let item = NSToolbarItem(itemIdentifier: identifier.subidentifier(index: index), barButtonItem: barButtonItem)
        item.toolTip = barButtonItem.title
        return item
      }
      self.init(itemIdentifier: identifier)
      self.subitems = subitems
    }
  }

  final class ToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
      Logger.sceneDelegate.trace("\(#function)")
      let groupIdentifier = NSToolbarItem.Identifier("org.brians-brain.center-item-groups")
      let groupIdentifiers = SavingTextEditViewController.centerItemGroups.indices
        .map { groupIdentifier.subidentifier(index: $0) }
        .interspersed(with: .space)
      var identifiers: [NSToolbarItem.Identifier] = [
        .toggleSidebar,
        .supplementarySidebarTrackingSeparatorItemIdentifier,
        .flexibleSpace,
      ]
      identifiers.append(contentsOf: groupIdentifiers)
      identifiers.append(.flexibleSpace)
      identifiers.append(.trailingItemGroups)

      return identifiers
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
      if let centerItemGroupIndex = NSToolbarItem.Identifier.centerItemGroups.subIdentifierIndex(from: itemIdentifier) {
        let centerItemGroups = SavingTextEditViewController.centerItemGroups
        guard centerItemGroups.indices.contains(centerItemGroupIndex) else {
          return nil
        }
        return NSToolbarItemGroup(identifier: itemIdentifier, barButtonGroup: centerItemGroups[centerItemGroupIndex])
      }
      if itemIdentifier == .trailingItemGroups {
        let barButtonItem = NotebookViewController.makeNewNoteButtonItem()
        let toolbarItem = NSToolbarItem(itemIdentifier: .trailingItemGroups, barButtonItem: barButtonItem)
        toolbarItem.toolTip = barButtonItem.title
        return toolbarItem
      }
      return nil
    }
  }
#endif
