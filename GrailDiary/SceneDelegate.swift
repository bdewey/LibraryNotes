//
//  SceneDelegate.swift
//  GrailDiary
//
//  Created by Brian Dewey on 1/9/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

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
        try openDocument(at: url, from: browser, createWelcomeContent: false, animated: false)
        didOpenSavedDocument = true
      } catch {
        Logger.shared.error("Unexpected error opening document: \(error.localizedDescription)")
      }
    }
    if !didOpenSavedDocument {
      Logger.shared.info("Trying to open the default document")
      // TODO
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

// MARK: - AppCommands

extension UIView {
  func makeDocumentBrowserButton() -> UIBarButtonItem? {
    guard let sceneDelegate = window?.windowScene?.delegate as? SceneDelegate else {
      Logger.shared.error("No window for view?")
      return nil
    }
    let button = UIBarButtonItem(title: "Open", style: .plain, target: sceneDelegate, action: #selector(SceneDelegate.openNewFile))
    button.accessibilityIdentifier = "open-files"
    return button
  }

  func makeNewNoteButton() -> UIBarButtonItem? {
    guard let sceneDelegate = window?.windowScene?.delegate as? SceneDelegate else {
      Logger.shared.error("No window for view?")
      return nil
    }
    let button = UIBarButtonItem(barButtonSystemItem: .compose, target: sceneDelegate, action: #selector(SceneDelegate.makeNewNote))
    button.accessibilityIdentifier = "new-document"
    return button
  }
}

// MARK: - UIDocumentBrowserViewControllerDelegate

extension SceneDelegate: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  private func openDocument(
    at url: URL,
    from controller: UIDocumentBrowserViewController,
    createWelcomeContent: Bool,
    animated: Bool
  ) throws {
    Logger.shared.info("Opening document at \"\(url.path)\"")
    let database: NoteDatabase
    if url.pathExtension == "grail" {
      database = NoteDatabase(fileURL: url)
    } else {
      throw CocoaError(CocoaError.fileReadUnsupportedScheme)
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
        if createWelcomeContent {
          database.tryCreatingWelcomeContent()
        }
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
    try? openDocument(at: url, from: controller, createWelcomeContent: false, animated: true)
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
      document.tryCreatingWelcomeContent()
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
    try? openDocument(at: destinationURL, from: controller, createWelcomeContent: false, animated: true)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Swift.Error?) {
    Logger.shared.error("Unable to import document at \(documentURL): \(error?.localizedDescription ?? "nil")")
  }
}

// MARK: - NoteDatabase

private extension NoteDatabase {
  /// Tries to create a "weclome" note in the database. Logs errors.
  func tryCreatingWelcomeContent() {
    if let welcomeURL = Bundle.main.url(forResource: "Welcome", withExtension: "md") {
      do {
        let welcomeMarkdown = try String(contentsOf: welcomeURL)
        let welcomeNote = Note(markdown: welcomeMarkdown)
        _ = try createNote(welcomeNote)
      } catch {
        Logger.shared.error("Unexpected error creating welcome content: \(error)")
      }
    }
  }
}

