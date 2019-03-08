// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import FlashcardKit
import MaterialComponents.MaterialAppBar
import MaterialComponents.MaterialSnackbar
import TextBundleKit
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

  private lazy var loadingViewController: UIViewController = {
    let loadingViewController = LoadingViewController(stylesheet: commonplaceBookStylesheet)
    loadingViewController.title = "Interactive Notebook"
    loadingViewController.delegate = self
    let navigationController = MDCAppBarNavigationController()
    navigationController.delegate = self
    navigationController.pushViewController(loadingViewController, animated: false)
    return navigationController
  }()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DDLog.add(DDTTYLogger.sharedInstance) // TTY = Xcode console

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = loadingViewController
    window.makeKeyAndVisible()

    makeMetadataProvider(completion: { metadataProviderResult in
      switch metadataProviderResult {
      case .success(let metadataProvider):
        let parsingRules = LanguageDeck.parsingRules
        window.rootViewController = self.makeViewController(
          notebook: Notebook(
            parsingRules: parsingRules,
            metadataProvider: metadataProvider
          ).loadCachedProperties().loadStudyMetadata().monitorMetadataProvider()
        )
      case .failure(let error):
        let messageText = "Error opening Notebook: \(error.localizedDescription)"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
      }

    })
    self.window = window
    return true
  }

  private func makeMetadataProvider(completion: @escaping (Result<FileMetadataProvider>) -> Void) {
    if CommandLine.arguments.contains("--uitesting") {
      do {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent("uitesting")
        let metadataProvider = try DirectoryMetadataProvider(
          container: container,
          deleteExistingContents: true
        )
        completion(.success(metadataProvider))
      } catch {
        completion(.failure(error))
      }
    } else {
      DispatchQueue.global(qos: .default).async {
        if let containerURL = FileManager.default.url(
          forUbiquityContainerIdentifier: "iCloud.org.brians-brain.commonplace-book"
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
  }

  private func makeViewController(
    notebook: Notebook
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
