// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CoreSpotlight
import Logging
import MiniMarkdown
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  let useCloud = true

  private enum Error: String, Swift.Error {
    case noCloud = "Not signed in to iCloud"
  }

  // This is here to force initialization of the CardTemplateType, which registers the class
  // with the type name. This has to be done before deserializing any card templates.
  private let knownCardTemplateTypes: [ChallengeTemplateType] = [
    .cloze,
    .quote,
    .vocabulary,
    .questionAndAnswer,
  ]

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController()
    loadingViewController.title = "Interactive Notebook"
    return loadingViewController
  }()

  var noteArchiveDocument: NoteStorage?
  /// If non-nil, we want to open this page initially upon opening the document.
  var initialPageIdentifier: Note.Identifier?

  @UserDefault("opened_document", defaultValue: nil) var openedDocumentBookmark: Data?
  @UserDefault("has_run_0", defaultValue: false) var hasRun: Bool

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let factory = LogHandlerFactory()
    // Here's how you enable debug logging for different loggers...
    // factory.logLevelsForLabel["org.brians-brain.MiniMarkdown"] = .debug
    LoggingSystem.bootstrap(factory.logHandler(for:))
    DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console

    let window = UIWindow(frame: UIScreen.main.bounds)

    let browser = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: ["org.brians-brain.notebundle", "org.brians-brain.notedb"])
    browser.delegate = self

    window.rootViewController = browser
    window.makeKeyAndVisible()
    self.window = window

    if !isUITesting, let openedDocumentBookmarkData = openedDocumentBookmark {
      DDLogInfo("Bookmark data exists for an open document")
      var isStale: Bool = false
      do {
        let url = try URL(resolvingBookmarkData: openedDocumentBookmarkData, bookmarkDataIsStale: &isStale)
        DDLogInfo("Successfully resolved url: \(url)")
        openDocument(at: url, from: browser, animated: false)
      } catch {
        DDLogError("Unexpected error: \(error.localizedDescription)")
      }
    } else if !(hasRun ?? false) || UIApplication.isSimulator {
      DDLogInfo("Trying to open the default document")
      openDefaultDocument(from: browser)
    }
    hasRun = true
    return true
  }

  private func openDefaultDocument(from viewController: UIDocumentBrowserViewController) {
    makeMetadataProvider(completion: { metadataProviderResult in
      switch metadataProviderResult {
      case .success(let metadataProvider):
        self.openDocument(at: metadataProvider.container.appendingPathComponent("archive.notedb"), from: viewController, animated: false)
      case .failure(let error):
        let messageText = "Error opening Notebook: \(error.localizedDescription)"
        let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        viewController.present(alertController, animated: true, completion: nil)
        self.loadingViewController.style = .error
      }
    })
  }

  func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    switch userActivity.activityType {
    case CSSearchableItemActionType:
      guard
        let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
      else {
        break
      }
      DDLogInfo("Opening page \(uniqueIdentifier)")
      initialPageIdentifier = Note.Identifier(rawValue: uniqueIdentifier)
    default:
      break
    }
    return true
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

  private lazy var isUITesting: Bool = {
    CommandLine.arguments.contains("--uitesting")
  }()

  private func makeMetadataProvider(completion: @escaping (Result<FileMetadataProvider, Swift.Error>) -> Void) {
    if isUITesting {
      let container = FileManager.default.temporaryDirectory.appendingPathComponent("uitesting")
      completion(makeDirectoryProvider(at: container, deleteExistingContents: true))
      return
    }
    let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!

    if UserDefaults.standard.value(forKey: "use_icloud") == nil {
      DDLogInfo("Setting default value for use_icloud")
      UserDefaults.standard.setValue(true, forKey: "use_icloud")
    }
    assert(UserDefaults.standard.value(forKey: "use_icloud") != nil)
    if UserDefaults.standard.bool(forKey: "use_icloud") {
      DDLogInfo("Trying to get documents from iCloud")
      makeICloudProvider { result in
        let innerResult = result.flatMapError { _ -> Result<FileMetadataProvider, Swift.Error> in
          DDLogInfo("Error getting iCloud documents; falling back to local")
          return self.makeDirectoryProvider(at: directoryURL)
        }
        completion(innerResult)
      }
    } else {
      completion(makeDirectoryProvider(at: directoryURL))
    }
  }

  private func wrapViewController(
    _ documentListViewController: DocumentListViewController
  ) -> UIViewController {
    let primaryNavigationController = UINavigationController(
      rootViewController: documentListViewController
    )
    primaryNavigationController.navigationBar.prefersLargeTitles = true

    let splitViewController = UISplitViewController(nibName: nil, bundle: nil)
    let detailViewController = UINavigationController(
      rootViewController:
      TextEditViewController.makeBlankDocument(
        notebook: documentListViewController.notebook,
        currentHashtag: nil,
        autoFirstResponder: false
      )
    )
    splitViewController.viewControllers = [primaryNavigationController, detailViewController]
    splitViewController.preferredDisplayMode = .allVisible
    splitViewController.delegate = self
    return splitViewController
  }
}

// MARK: - UIDocumentBrowserViewControllerDelegate

extension AppDelegate: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  private func openDocument(at url: URL, from controller: UIDocumentBrowserViewController, animated: Bool) {
    DDLogInfo("Opening document at \(url)")
    let noteArchiveDocument: NoteStorage
    if url.pathExtension == "notebundle" {
      noteArchiveDocument = NoteDocumentStorage(
        fileURL: url,
        parsingRules: ParsingRules.commonplace
      )
    } else if url.pathExtension == "notedb" {
      noteArchiveDocument = NoteSqliteStorage(fileURL: url, parsingRules: ParsingRules.commonplace)
    } else {
      assertionFailure("Unknown note format: \(url.pathExtension)")
      return
    }
    DDLogInfo("Using document at \(noteArchiveDocument.fileURL)")
    let documentListViewController = DocumentListViewController(notebook: noteArchiveDocument)
    documentListViewController.didTapFilesAction = { [weak self] in
      if UIApplication.isSimulator {
        let messageText = "Document browser doesn't work in the simulator"
        let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        documentListViewController.present(alertController, animated: true, completion: nil)
      } else {
        self?.openedDocumentBookmark = nil
        documentListViewController.dismiss(animated: true, completion: nil)
      }
    }
    let wrappedViewController: UIViewController = wrapViewController(documentListViewController)
    wrappedViewController.modalPresentationStyle = .fullScreen
    wrappedViewController.modalTransitionStyle = .crossDissolve
    controller.present(wrappedViewController, animated: animated, completion: nil)
    let noteIdentifierCopy = initialPageIdentifier
    noteArchiveDocument.open(completionHandler: { success in
      noteIdentifierCopy.flatMap { documentListViewController.showPage(with: $0) }
      let properties: [String: String] = [
        "Success": success.description,
//        "documentState": String(describing: noteArchiveDocument.documentState),
//        "previousError": noteArchiveDocument.previousError?.localizedDescription ?? "nil",
      ]
      DDLogInfo("In open completion handler. \(properties)")
      if success, !self.isUITesting {
        self.openedDocumentBookmark = try? url.bookmarkData()
      }
    })
    initialPageIdentifier = nil
    self.noteArchiveDocument = noteArchiveDocument
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard let url = documentURLs.first else { return }
    openDocument(at: url, from: controller, animated: true)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
    let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    let url = directoryURL.appendingPathComponent("commonplace").appendingPathExtension("notedb")
    do {
      let document = NoteSqliteStorage(fileURL: url, parsingRules: ParsingRules.commonplace)
      try document.open()
      try document.flush()
    } catch {
      DDLogError("Error creating new document: \(error)")
      importHandler(nil, .none)
      return
    }
    importHandler(url, .copy)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    DDLogInfo("Imported document to \(destinationURL)")
    openDocument(at: destinationURL, from: controller, animated: true)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Swift.Error?) {
    DDLogError("Unable to import document at \(documentURL): \(error?.localizedDescription ?? "nil")")
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
