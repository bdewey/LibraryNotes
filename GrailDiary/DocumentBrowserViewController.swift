// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import KeyValueCRDT
import Logging
import UIKit
import UniformTypeIdentifiers

@objc protocol AppCommands {
  func openNewFile()
}

/// Our custom DocumentBrowserViewController that knows how to open new files, etc.
final class DocumentBrowserViewController: UIDocumentBrowserViewController {
  override init(forOpening contentTypes: [UTType]?) {
    super.init(forOpening: contentTypes)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    delegate = self
    restorationIdentifier = "DocumentBrowserViewController"
  }

  private var topLevelViewController: NotebookViewController?

  private let documentURLKey = "documentURLBookmarkData"

  private enum ActivityKey {
    static let openDocumentActivity = "org.brians-brain.GrailDiary.OpenNotebook"
    static let documentURL = "org.brians-brain.GrailDiary.OpenNotebook.URL"
  }

  /// Makes a NSUserActivity that captures the current state of this UI.
  func makeUserActivity() -> NSUserActivity? {
    guard let notebookViewController = topLevelViewController else {
      return nil
    }
    let url = notebookViewController.fileURL
    do {
      let urlData = try url.bookmarkData()
      let activity = NSUserActivity(activityType: ActivityKey.openDocumentActivity)
      activity.title = "View Notebook"
      activity.addUserInfoEntries(from: [ActivityKey.documentURL: urlData])
      topLevelViewController?.updateUserActivity(activity)
      return activity
    } catch {
      Logger.shared.error("Unexpected error creating user activity: \(error)")
      return nil
    }
  }

  func configure(with userActivity: NSUserActivity) {
    guard let urlData = userActivity.userInfo?[ActivityKey.documentURL] as? Data else {
      Logger.shared.error("In DocumentBrowserViewController.configure(with:), but cannot get URL from activity")
      return
    }
    do {
      var isStale = false
      let url = try URL(resolvingBookmarkData: urlData, bookmarkDataIsStale: &isStale)
      try openDocument(at: url, createWelcomeContent: false, animated: false) { [self] _ in
        self.topLevelViewController?.configure(with: userActivity)
      }
    } catch {
      Logger.shared.error("Error opening saved document: \(error)")
    }
  }
}

extension DocumentBrowserViewController: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  func openDocument(
    at url: URL,
    createWelcomeContent: Bool,
    animated: Bool,
    completion: ((Bool) -> Void)? = nil
  ) throws {
    Logger.shared.info("Opening document at \"\(url.path)\"")
    let database: NoteDatabase
    if url.pathExtension == "kvcrdt" {
      guard let author = Author(.current) else {
        throw NoteDatabaseError.noDeviceUUID
      }
      database = try NoteDatabase(fileURL: url, author: author)
    } else {
      throw CocoaError(CocoaError.fileReadUnsupportedScheme)
    }
    Logger.shared.info("Using document at \(database.fileURL)")
    Task {
      let success = await database.open()
      let properties: [String: String] = [
        "Success": success.description,
        "documentState": String(describing: database.documentState),
      ]
      Logger.shared.info("In open completion handler. \(properties)")
      if success, !AppDelegate.isUITesting {
        if createWelcomeContent {
          database.tryCreatingWelcomeContent()
        }
      }
      let viewController = NotebookViewController(database: database)
      viewController.modalPresentationStyle = .fullScreen
      viewController.modalTransitionStyle = .crossDissolve
      viewController.view.tintColor = .systemOrange
      self.present(viewController, animated: animated, completion: nil)
      self.topLevelViewController = viewController
      completion?(success)
    }
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard let url = documentURLs.first else {
      return
    }
    try? openDocument(at: url, createWelcomeContent: false, animated: true)
  }

  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void
  ) {
    Task {
      do {
        let url = try await makeNewDocument()
        importHandler(url, .move)
      } catch {
        importHandler(nil, .none)
      }
    }
  }

  private func makeNewDocument() async throws -> URL? {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    let url = directoryURL.appendingPathComponent("diary").appendingPathExtension("kvcrdt")
    let author = Author(UIDevice.current)!
    let document = try NoteDatabase(fileURL: url, author: author)
    Logger.shared.info("Attempting to create a document at \(url.path)")
    guard await document.open() else {
      return nil
    }
    document.tryCreatingWelcomeContent()
    guard await document.save(to: url, for: .forCreating) else {
      return nil
    }
    return url
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    Logger.shared.info("Imported document to \(destinationURL)")
    try? openDocument(at: destinationURL, createWelcomeContent: false, animated: true)
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Swift.Error?) {
    Logger.shared.error("Unable to import document at \(documentURL): \(error?.localizedDescription ?? "nil")")
  }
}

// MARK: - AppCommands

//
// Implements system-wide menu responses
extension DocumentBrowserViewController: AppCommands {
  @objc func openNewFile() {
    topLevelViewController = nil
    dismiss(animated: true, completion: nil)
  }

  @objc func makeNewNote() {
    topLevelViewController?.makeNewNote()
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
