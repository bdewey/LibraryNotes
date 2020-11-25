//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import CoreSpotlight
import Logging
import UIKit

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

  // This is here to force initialization of the CardTemplateType, which registers the class
  // with the type name. This has to be done before deserializing any card templates.
  private let knownCardTemplateTypes: [ChallengeTemplateType] = [
    .cloze,
    .quote,
    .questionAndAnswer,
  ]

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController()
    loadingViewController.title = AppDelegate.appName
    return loadingViewController
  }()

  /// The currently open NoteStorage. TODO: Pick a consistent name for this thing!
  var noteArchiveDocument: NoteStorage?
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
    var factory = LogHandlerFactory()
    // Here's how you enable debug logging for different loggers...
    factory.logLevelsForLabel[Logger.sharedLoggerLabel] = .debug
    LoggingSystem.bootstrap(factory.logHandler(for:))

    let window = UIWindow(frame: UIScreen.main.bounds)

    let browser = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: ["org.brians-brain.graildiary"])
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
        let messageText = "Error opening Notebook: \(error.localizedDescription)"
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
    if UIApplication.isSimulator, false {
      let messageText = "Document browser doesn't work in the simulator"
      let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
      let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
      alertController.addAction(okAction)
      documentListViewController.present(alertController, animated: true, completion: nil)
    } else {
      AppDelegate.openedDocumentBookmark = nil
      documentListViewController.dismiss(animated: true, completion: nil)
    }
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
    let noteArchiveDocument: NoteStorage
    if url.pathExtension == "grail" {
      noteArchiveDocument = NoteSqliteStorage(fileURL: url)
    } else {
      throw Error.unknownFormat
    }
    Logger.shared.info("Using document at \(noteArchiveDocument.fileURL)")
    let viewController = NotebookViewController(notebook: noteArchiveDocument)
    viewController.modalPresentationStyle = .fullScreen
    viewController.modalTransitionStyle = .crossDissolve
    viewController.view.tintColor = .systemOrange
    controller.present(viewController, animated: animated, completion: nil)
    noteArchiveDocument.open(completionHandler: { success in
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
    self.noteArchiveDocument = noteArchiveDocument
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard let url = documentURLs.first else { return }
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
    let document = NoteSqliteStorage(fileURL: url)
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

struct LogHandlerFactory {
  var defaultLogLevel = Logger.Level.info
  var logLevelsForLabel = [String: Logger.Level]()

  func logHandler(for label: String) -> LogHandler {
    var handler = StreamLogHandler.standardError(label: label)
    handler.logLevel = logLevelsForLabel[label, default: defaultLogLevel]
    return handler
  }
}
