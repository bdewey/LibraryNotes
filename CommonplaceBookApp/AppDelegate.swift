// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CoreSpotlight
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
  ]

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController()
    loadingViewController.title = "Interactive Notebook"
    return loadingViewController
  }()

  var noteArchiveDocument: NoteArchiveDocument?
  /// If non-nil, we want to open this page initially upon opening the document.
  var initialPageIdentifier: String?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console

    let window = UIWindow(frame: UIScreen.main.bounds)

    let browser = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: ["org.brians-brain.notebundle"])
    browser.delegate = self

    window.rootViewController = browser
    window.makeKeyAndVisible()
    self.window = window
    return true
  }

//  func applicationDidBecomeActive(_ application: UIApplication) {
//    guard let window = window, noteArchiveDocument == nil else { return }
//    let parsingRules = ParsingRules.commonplace
//    makeMetadataProvider(completion: { metadataProviderResult in
//      switch metadataProviderResult {
//      case .success(let metadataProvider):
//        let noteArchiveDocument = NoteArchiveDocument(
//          fileURL: metadataProvider.container.appendingPathComponent("archive.notebundle"),
//          parsingRules: parsingRules
//        )
//        DDLogInfo("Using document at \(noteArchiveDocument.fileURL)")
//        let documentListViewController = DocumentListViewController(notebook: noteArchiveDocument)
//        window.rootViewController = self.wrapViewController(
//          documentListViewController
//        )
//        let pageIdentifierCopy = self.initialPageIdentifier
//        noteArchiveDocument.open(completionHandler: { success in
//          pageIdentifierCopy.flatMap { documentListViewController.showPage(with: $0) }
//          DDLogInfo("In open completion handler. Success = \(success), documentState = \(noteArchiveDocument.documentState), previousError = \(noteArchiveDocument.previousError)")
//          metadataProvider.queryForCurrentFileMetadata(completion: { fileMetadataItems in
//            noteArchiveDocument.importFileMetadataItems(
//              fileMetadataItems,
//              from: metadataProvider,
//              importDate: Date()
//            )
//          })
//        })
//        self.initialPageIdentifier = nil
//        self.noteArchiveDocument = noteArchiveDocument
//      case .failure(let error):
//        let messageText = "Error opening Notebook: \(error.localizedDescription)"
//        let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
//        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
//        alertController.addAction(okAction)
//        window.rootViewController?.present(alertController, animated: true, completion: nil)
//        self.loadingViewController.style = .error
//      }
//    })
//  }

//  func applicationDidEnterBackground(_ application: UIApplication) {
//    guard let document = noteArchiveDocument else { return }
//    if document.hasUnsavedChanges {
//      document.save(to: document.fileURL, for: .forOverwriting, completionHandler: nil)
//    }
//    noteArchiveDocument = nil
//  }

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
      self.initialPageIdentifier = uniqueIdentifier
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

  private func makeMetadataProvider(completion: @escaping (Result<FileMetadataProvider, Swift.Error>) -> Void) {
    if CommandLine.arguments.contains("--uitesting") {
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
    splitViewController.viewControllers = [primaryNavigationController, EmptyViewController()]
    splitViewController.preferredDisplayMode = .allVisible
    splitViewController.delegate = self
    return splitViewController
  }
}

// MARK: - UIDocumentBrowserViewControllerDelegate

extension AppDelegate: UIDocumentBrowserViewControllerDelegate {
  fileprivate func openDocument(at url: URL, from controller: UIDocumentBrowserViewController) {
    DDLogInfo("Opening document at \(url)")
    let noteArchiveDocument = NoteArchiveDocument(
      fileURL: url,
      parsingRules: ParsingRules.commonplace
    )
    DDLogInfo("Using document at \(noteArchiveDocument.fileURL)")
    let documentListViewController = DocumentListViewController(notebook: noteArchiveDocument)
    let wrappedViewController: UIViewController = self.wrapViewController(documentListViewController)
    controller.present(wrappedViewController, animated: true, completion: nil)
    let pageIdentifierCopy = self.initialPageIdentifier
    noteArchiveDocument.open(completionHandler: { success in
      pageIdentifierCopy.flatMap { documentListViewController.showPage(with: $0) }
      DDLogInfo("In open completion handler. Success = \(success), documentState = \(noteArchiveDocument.documentState), previousError = \(noteArchiveDocument.previousError)")
    })
    self.initialPageIdentifier = nil
    self.noteArchiveDocument = noteArchiveDocument
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard let url = documentURLs.first else { return }
    openDocument(at: url, from: controller)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
    let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    let url = directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("notebundle")
    let document = NoteArchiveDocument(fileURL: url, parsingRules: ParsingRules.commonplace)
    document.save(to: url, for: .forCreating) { saveSuccess in
      guard saveSuccess else {
        DDLogError("Could not save document to \(url): \(document.previousError?.localizedDescription ?? "nil")")
        importHandler(nil, .none)
        return
      }
      document.close { closeSuccess in
        guard closeSuccess else {
          DDLogError("Could not close document at \(url): \(document.previousError?.localizedDescription ?? "nil")")
          importHandler(nil, .none)
          return
        }
        importHandler(url, .copy)
      }
    }
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    DDLogInfo("Imported document to \(destinationURL)")
    openDocument(at: destinationURL, from: controller)
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
      let textEditViewController = navigationController.visibleViewController as? TextEditViewController
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
    return textEditViewController.pageIdentifier == nil
  }
}
