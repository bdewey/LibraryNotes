// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MaterialComponents.MaterialAppBar
import MaterialComponents.MaterialSnackbar
import MiniMarkdown
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, LoadingViewControllerDelegate {
  var window: UIWindow?
  let useCloud = true

  private enum Error: String, Swift.Error {
    case noCloud = "Not signed in to iCloud"
  }

  // This is here to force initialization of the CardTemplateType, which registers the class
  // with the type name. This has to be done before deserializing any card templates.
  private let knownCardTemplateTypes: [ChallengeTemplateType] = [
    .vocabularyAssociation,
    .cloze,
    .quote,
  ]

  private lazy var loadingViewController: LoadingViewController = {
    let loadingViewController = LoadingViewController(stylesheet: commonplaceBookStylesheet)
    loadingViewController.title = "Interactive Notebook"
    loadingViewController.delegate = self
    return loadingViewController
  }()

  var noteArchiveDocument: NoteArchiveDocument?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console

    let window = UIWindow(frame: UIScreen.main.bounds)

    let navigationController = MDCAppBarNavigationController()
    navigationController.delegate = self
    navigationController.pushViewController(loadingViewController, animated: false)
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    self.window = window
    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    guard let window = window, noteArchiveDocument == nil else { return }
    let parsingRules = ParsingRules.commonplace
    makeMetadataProvider(completion: { metadataProviderResult in
      switch metadataProviderResult {
      case .success(let metadataProvider):
        let noteArchiveDocument = NoteArchiveDocument(
          fileURL: metadataProvider.container.appendingPathComponent("archive.notebundle"),
          parsingRules: parsingRules
        )
        DDLogInfo("Using document at \(noteArchiveDocument.fileURL)")
        noteArchiveDocument.open(completionHandler: { success in
          DDLogInfo("In open completion handler. Success = \(success), documentState = \(noteArchiveDocument.documentState), previousError = \(noteArchiveDocument.previousError)")
          metadataProvider.queryForCurrentFileMetadata(completion: { fileMetadataItems in
            noteArchiveDocument.importFileMetadataItems(
              fileMetadataItems,
              from: metadataProvider,
              importDate: Date()
            )
          })
        })
        self.noteArchiveDocument = noteArchiveDocument
        window.rootViewController = self.makeViewController(
          notebook: noteArchiveDocument
        )
      case .failure(let error):
        let messageText = "Error opening Notebook: \(error.localizedDescription)"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
        self.loadingViewController.style = .error
      }
    })
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    guard let document = noteArchiveDocument else { return }
    if document.hasUnsavedChanges {
      document.save(to: document.fileURL, for: .forOverwriting, completionHandler: nil)
    }
    noteArchiveDocument = nil
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

  private func makeViewController(
    notebook: NoteArchiveDocument
  ) -> UIViewController {
    let navigationController = MDCAppBarNavigationController()
    navigationController.delegate = self
    navigationController.pushViewController(
      DocumentListViewController(
        notebook: notebook,
        stylesheet: commonplaceBookStylesheet
      ),
      animated: false
    )
    return navigationController
  }

  func loadingViewControllerCycleColors(_ viewController: LoadingViewController) -> [UIColor] {
    return [commonplaceBookStylesheet.colors.secondaryColor]
  }
}

extension LoadingViewController: StylesheetContaining {}

private let commonplaceBookStylesheet: Stylesheet = {
  var stylesheet = Stylesheet()
  stylesheet.colors.primaryColor = UIColor.white
  stylesheet.colors.onPrimaryColor = UIColor.black
  stylesheet.colors.secondaryColor = UIColor(rgb: 0x661FFF)
  stylesheet.colors.onSecondaryColor = UIColor.white
  stylesheet.colors.surfaceColor = UIColor.white
  stylesheet.typographyScheme.headline6 = UIFont(name: "LibreFranklin-Medium", size: 20.0)!
  stylesheet.typographyScheme.body2 = UIFont(name: "LibreFranklin-Regular", size: 14.0)!
  stylesheet.typographyScheme.caption = UIFont(name: "Merriweather-Light", size: 11.4)!
  stylesheet.typographyScheme.subtitle1 = UIFont(name: "LibreFranklin-SemiBold", size: 15.95)!
  stylesheet.kern[.headline6] = 0.25
  stylesheet.kern[.body2] = 0.25
  stylesheet.kern[.caption] = 0.4
  stylesheet.kern[.subtitle1] = 0.15
  return stylesheet
}()

extension UIViewController {
  var semanticColorScheme: MDCColorScheming {
    if let container = self as? StylesheetContaining {
      return container.stylesheet.colors.semanticColorScheme
    } else {
      return MDCSemanticColorScheme(defaults: .material201804)
    }
  }

  var typographyScheme: MDCTypographyScheme {
    if let container = self as? StylesheetContaining {
      return container.stylesheet.typographyScheme
    } else {
      return MDCTypographyScheme(defaults: .material201804)
    }
  }
}

extension AppDelegate: MDCAppBarNavigationControllerDelegate {
  func appBarNavigationController(
    _ navigationController: MDCAppBarNavigationController,
    willAdd appBar: MDCAppBar,
    asChildOf viewController: UIViewController
  ) {
    MDCAppBarColorThemer.applySemanticColorScheme(
      viewController.semanticColorScheme,
      to: appBar
    )
    MDCAppBarTypographyThemer.applyTypographyScheme(
      viewController.typographyScheme,
      to: appBar
    )
    if var forwarder = viewController as? MDCScrollEventForwarder {
      forwarder.headerView = appBar.headerViewController.headerView
      appBar.headerViewController.headerView.observesTrackingScrollViewScrollEvents = false
      appBar.headerViewController.headerView.shiftBehavior = forwarder.desiredShiftBehavior
    }
  }
}
