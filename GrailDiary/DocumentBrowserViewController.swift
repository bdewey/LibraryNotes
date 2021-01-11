// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import UIKit
import UniformTypeIdentifiers

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

/// Our custom DocumentBrowserViewController that knows how to open new files, etc.
final class DocumentBrowserViewController: UIDocumentBrowserViewController {
  override init(forOpening contentTypes: [UTType]?) {
    super.init(forOpening: contentTypes)
    delegate = self
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    delegate = self
  }

  private var topLevelViewController: NotebookViewController?
}

extension DocumentBrowserViewController: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  func openDocument(
    at url: URL,
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
    present(viewController, animated: animated, completion: nil)
    database.open(completionHandler: { success in
      let properties: [String: String] = [
        "Success": success.description,
//        "documentState": String(describing: noteArchiveDocument.documentState),
//        "previousError": noteArchiveDocument.previousError?.localizedDescription ?? "nil",
      ]
      Logger.shared.info("In open completion handler. \(properties)")
      if success, !AppDelegate.isUITesting {
        if createWelcomeContent {
          database.tryCreatingWelcomeContent()
        }
        AppDelegate.openedDocumentBookmark = try? url.bookmarkData()
      }
    })
    topLevelViewController = viewController
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
      present(alert, animated: true, completion: nil)
      Logger.shared.info("Trying to open \(documentURLs.first?.lastPathComponent ?? "nil") but it isn't a Grail Diary file")
      return
    }
    try? openDocument(at: url, createWelcomeContent: false, animated: true)
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
    AppDelegate.openedDocumentBookmark = nil
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
