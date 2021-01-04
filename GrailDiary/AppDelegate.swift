// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CoreSpotlight
import FileLogging
import Logging
import UIKit

extension UTType {
  static let grailDiary = UTType("org.brians-brain.graildiary")!
}

extension Logger {
  fileprivate static let sharedLoggerLabel = "org.brians-brain.grail-diary"
  public static let shared = Logger(label: sharedLoggerLabel)
}

@objc protocol AppCommands {
  func makeNewNote()
  func openNewFile()
}

enum AppCommandsButtonItems {
  static func documentBrowser() -> UIBarButtonItem {
    let button = UIBarButtonItem(title: "Open", style: .plain, target: nil, action: #selector(AppCommands.openNewFile))
    button.accessibilityIdentifier = "open-files"
    return button
  }

  static func newNote() -> UIBarButtonItem {
    let button = UIBarButtonItem(barButtonSystemItem: .compose, target: nil, action: #selector(AppCommands.makeNewNote))
    button.accessibilityIdentifier = "new-document"
    return button
  }
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  static let didRequestOpenFileNotification = NSNotification.Name(rawValue: "org.brians-brain.didRequestOpenFile")

  var window: UIWindow?
  let useCloud = true

  public static let appName = "Grail Diary"

  private enum Error: String, Swift.Error {
    case noCloud = "Not signed in to iCloud"
    case unknownFormat = "Unknown file format"
  }

  // This is here to force initialization of the PromptType, which registers the class
  // with the type name. This has to be done before deserializing any prompt collections.
  private let knownPromptTypes: [PromptType] = [
    .cloze,
    .quote,
    .questionAndAnswer,
  ]

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController()
    loadingViewController.title = AppDelegate.appName
    return loadingViewController
  }()

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

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let factory = LogHandlerFactory()
    // Here's how you enable debug logging for different loggers...
    factory.logLevelsForLabel[Logger.sharedLoggerLabel] = .debug
    factory.logLevelsForLabel[Logger.webViewLoggerLabel] = .debug
    LoggingSystem.bootstrap(factory.logHandler(for:))

    Logger.shared.info("----- Launch application version \(UIApplication.versionString)")
    let window = UIWindow(frame: UIScreen.main.bounds)

    let browser = UIDocumentBrowserViewController(forOpening: [.grailDiary, .plainText])
    browser.delegate = self

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
        try openDocument(at: url, from: browser, animated: false)
        didOpenSavedDocument = true
      } catch {
        Logger.shared.error("Unexpected error opening document: \(error.localizedDescription)")
      }
    }
    if !didOpenSavedDocument {
      Logger.shared.info("Trying to open the default document")
      openDefaultDocument(from: browser)
    }
    return true
  }

  private func openDefaultDocument(from viewController: UIDocumentBrowserViewController) {
    makeMetadataProvider(completion: { metadataProviderResult in
      let openResult = metadataProviderResult.flatMap { metadataProvider in
        Result {
          try self.openDocument(at: metadataProvider.container.appendingPathComponent("diary.grail"), from: viewController, animated: false)
        }
      }
      if case .failure(let error) = openResult {
        let messageText = "Error opening database: \(error.localizedDescription)"
        let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        viewController.present(alertController, animated: true, completion: nil)
        self.loadingViewController.style = .error
      }
    })
  }

  private func makeDirectoryProvider(
    at container: URL,
    deleteExistingContents: Bool = false
  ) -> Result<FileMetadataProvider, Swift.Error> {
    return Result {
      try DirectoryMetadataProvider(
        container: container,
        deleteExistingContents: deleteExistingContents
      )
    }
  }

  private func makeICloudProvider(
    completion: @escaping (Result<FileMetadataProvider, Swift.Error>) -> Void
  ) {
    DispatchQueue.global(qos: .default).async {
      if let containerURL = FileManager.default.url(
        forUbiquityContainerIdentifier: "iCloud.org.brians-brain.CommonplaceBookApp"
      ) {
        DispatchQueue.main.async {
          let metadataProvider = ICloudFileMetadataProvider(
            container: containerURL.appendingPathComponent("Documents")
          )
          completion(.success(metadataProvider))
        }
      } else {
        DispatchQueue.main.async {
          completion(.failure(Error.noCloud))
        }
      }
    }
  }

  internal static var isUITesting: Bool = {
    CommandLine.arguments.contains("--uitesting")
  }()

  private func makeMetadataProvider(completion: @escaping (Result<FileMetadataProvider, Swift.Error>) -> Void) {
    if Self.isUITesting {
      let container = FileManager.default.temporaryDirectory.appendingPathComponent("uitesting")
      completion(makeDirectoryProvider(at: container, deleteExistingContents: true))
      return
    }
    let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!

    if UserDefaults.standard.value(forKey: "use_icloud") == nil {
      Logger.shared.info("Setting default value for use_icloud")
      UserDefaults.standard.setValue(true, forKey: "use_icloud")
    }
    assert(UserDefaults.standard.value(forKey: "use_icloud") != nil)
    if UserDefaults.standard.bool(forKey: "use_icloud") {
      Logger.shared.info("Trying to get documents from iCloud")
      makeICloudProvider { result in
        let innerResult = result.flatMapError { _ -> Result<FileMetadataProvider, Swift.Error> in
          Logger.shared.info("Error getting iCloud documents; falling back to local")
          return self.makeDirectoryProvider(at: directoryURL)
        }
        completion(innerResult)
      }
    } else {
      completion(makeDirectoryProvider(at: directoryURL))
    }
  }
}

// MARK: - AppCommands

//
// Implements system-wide menu responses
extension AppDelegate: AppCommands {
  @objc func openNewFile() {
    guard let documentListViewController = window?.rootViewController else {
      return
    }
    AppDelegate.openedDocumentBookmark = nil
    documentListViewController.dismiss(animated: true, completion: nil)
  }

  @objc func makeNewNote() {
    topLevelViewController?.makeNewNote()
  }
}

// MARK: - UIDocumentBrowserViewControllerDelegate

extension AppDelegate: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  private func openDocument(at url: URL, from controller: UIDocumentBrowserViewController, animated: Bool) throws {
    Logger.shared.info("Opening document at \"\(url.path)\"")
    let database: NoteDatabase
    if url.pathExtension == "grail" {
      database = NoteDatabase(fileURL: url)
    } else {
      throw Error.unknownFormat
    }
    Logger.shared.info("Using document at \(database.fileURL)")
    let viewController = NotebookViewController(database: database)
    viewController.modalPresentationStyle = .fullScreen
    viewController.modalTransitionStyle = .crossDissolve
    viewController.view.tintColor = .systemOrange
    controller.present(viewController, animated: animated, completion: nil)
    database.open(completionHandler: { success in
      let properties: [String: String] = [
        "Success": success.description,
//        "documentState": String(describing: noteArchiveDocument.documentState),
//        "previousError": noteArchiveDocument.previousError?.localizedDescription ?? "nil",
      ]
      Logger.shared.info("In open completion handler. \(properties)")
      if success, !Self.isUITesting {
        Self.openedDocumentBookmark = try? url.bookmarkData()
      }
    })
    topLevelViewController = viewController
    self.database = database
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard
      let url = documentURLs.first,
      let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
      values.contentType?.conforms(to: .grailDiary) ?? false
    else {
      let alert = UIAlertController(title: "Oops", message: "Cannot open this file type", preferredStyle: .alert)
      let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
      alert.addAction(okAction)
      window?.rootViewController?.present(alert, animated: true, completion: nil)
      Logger.shared.info("Trying to open \(documentURLs.first?.lastPathComponent ?? "nil") but it isn't a Grail Diary file")
      return
    }
    try? openDocument(at: url, from: controller, animated: true)
  }

  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void
  ) {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
      Logger.shared.info("Created directory at \(directoryURL)")
    } catch {
      Logger.shared.error("Unable to create temporary directory at \(directoryURL.path): \(error)")
      importHandler(nil, .none)
    }
    let url = directoryURL.appendingPathComponent("diary").appendingPathExtension("grail")
    let document = NoteDatabase(fileURL: url)
    Logger.shared.info("Attempting to create a document at \(url.path)")
    document.open { openSuccess in
      guard openSuccess else {
        Logger.shared.error("Could not open document")
        importHandler(nil, .none)
        return
      }
      document.save(to: url, for: .forCreating) { saveSuccess in
        if saveSuccess {
          importHandler(url, .move)
        } else {
          Logger.shared.error("Could not create document")
          importHandler(nil, .none)
        }
      }
    }
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    Logger.shared.info("Imported document to \(destinationURL)")
    try? openDocument(at: destinationURL, from: controller, animated: true)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Swift.Error?) {
    Logger.shared.error("Unable to import document at \(documentURL): \(error?.localizedDescription ?? "nil")")
  }
}

// MARK: - UISplitViewControllerDelegate

extension AppDelegate: UISplitViewControllerDelegate {
  func splitViewController(
    _ splitViewController: UISplitViewController,
    collapseSecondary secondaryViewController: UIViewController,
    onto primaryViewController: UIViewController
  ) -> Bool {
    guard
      let navigationController = secondaryViewController as? UINavigationController,
      let textEditViewController = navigationController.visibleViewController as? SavingTextEditViewController
    else {
      assertionFailure()
      return false
    }
    // Per documentation:
    // Return false to let the split view controller try and incorporate the secondary view
    // controller’s content into the collapsed interface or true to indicate that you do not want
    // the split view controller to do anything with the secondary view controller.
    //
    // In our case, if the textEditViewController doesn't represent a real page, we don't
    // want to show it.
    return textEditViewController.noteIdentifier == nil
  }

  func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
    return .supplementary
  }
}

/// Creates log handlers. Note that since this tends to run before logging is set up, and if it fails we can't get debug information for other bugs,
/// the strategy here is to crash on unexpected errors rather than "log and try to recover."
// swiftlint:disable force_try
final class LogHandlerFactory {
  var defaultLogLevel = Logger.Level.info
  var logLevelsForLabel = [String: Logger.Level]()

  func logHandler(for label: String) -> LogHandler {
    var streamHandler = StreamLogHandler.standardError(label: label)
    streamHandler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]

    return MultiplexLogHandler([
      streamHandler,
      makeFileLogHandler(label: label),
    ])
  }

  private func makeFileLogHandler(label: String) -> FileLogHandler {
    let handler = try! FileLogHandler(label: label, localFile: logFileURL)
    handler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]
    return handler
  }

  /// the URL to use for **the current logging session**
  private lazy var logFileURL: URL = {
    let currentLogFileURL = logFileDirectoryURL.appendingPathComponent("grail-diary-current.log")
    if
      let existingAttributes = try? FileManager.default.attributesOfItem(atPath: currentLogFileURL.path),
      let existingSize = (existingAttributes[.size] as? Int),
      existingSize > 1024 * 1024
    {
      // Roll the log.
      let creationDate = (existingAttributes[.creationDate] as? Date) ?? Date()
      let unwantedCharacters = CharacterSet(charactersIn: "-:")
      var dateString = ISO8601DateFormatter().string(from: creationDate)
      dateString.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })
      let archiveLogFileURL = logFileDirectoryURL.appendingPathComponent("grail-diary-\(dateString).log")
      try! FileManager.default.moveItem(at: currentLogFileURL, to: archiveLogFileURL)
    }
    return currentLogFileURL
  }()

  /// The container directory for all of our log files.
  private lazy var logFileDirectoryURL: URL = {
    // Right now, put the logs into the Documents directory so they're easy to find.
    let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let logDirectoryURL = documentsDirectoryURL.appendingPathComponent("logs")
    // Try to create the "logs" subdirectory if it does not exist.
    try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: false, attributes: nil)
    return logDirectoryURL
  }()
}
