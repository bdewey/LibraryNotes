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
    Task {
      do {
        var isStale = false
        let url = try URL(resolvingBookmarkData: urlData, bookmarkDataIsStale: &isStale)
        try await openDocument(at: url, animated: false)
        topLevelViewController?.configure(with: userActivity)
      } catch {
        Logger.shared.error("Error opening saved document: \(error)")
      }
    }
  }
}

extension DocumentBrowserViewController: UIDocumentBrowserViewControllerDelegate {
  /// Opens a document.
  /// - parameter url: The URL of the document to open
  /// - parameter controller: The view controller from which to present the DocumentListViewController
  @MainActor
  func openDocument(
    at url: URL,
    animated: Bool
  ) async throws {
    Logger.shared.info("Opening document at \"\(url.path)\"")
    let database: NoteDatabase
    if url.pathExtension == UTType.libnotes.preferredFilenameExtension || url.pathExtension == "kvcrdt" {
      database = try await NoteDatabase(fileURL: url, authorDescription: UIDevice.current.name)
    } else {
      throw CocoaError(CocoaError.fileReadUnsupportedScheme)
    }
    Logger.shared.info("Using document at \(database.fileURL)")
    let properties: [String: String] = [
      "documentState": String(describing: database.documentState),
    ]
    Logger.shared.info("In open completion handler. \(properties)")
    let viewController = NotebookViewController(database: database)
    viewController.modalPresentationStyle = .fullScreen
    viewController.modalTransitionStyle = .crossDissolve
    viewController.view.tintColor = .systemOrange
    present(viewController, animated: animated, completion: nil)
    topLevelViewController = viewController
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
    guard let url = documentURLs.first else {
      return
    }
    Task {
      do {
        try await openDocument(at: url, animated: true)
      } catch {
        Logger.shared.error("Unexpected error opening document at \(url): \(error)")
      }
    }
  }

  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void
  ) {
    Task {
      do {
        guard let url = try await makeNewDocument() else {
          assertionFailure()
          importHandler(nil, .none)
          return
        }
        Logger.shared.info("Trying to import from '\(url.path)'")
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
          try FileManager.default.removeItem(at: temporaryURL)
        }
        try FileManager.default.copyItem(at: url, to: temporaryURL)
        importHandler(temporaryURL, .move)
      } catch {
        Logger.shared.error("Unexpected error creating document: \(error)")
        importHandler(nil, .none)
      }
    }
  }

  private func makeNewDocument() async throws -> URL? {
    Bundle.main.url(forResource: "library", withExtension: "libnotes")
  }

  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    Logger.shared.info("Imported document to \(destinationURL)")
    Task {
      do {
        try await openDocument(at: destinationURL, animated: true)
      } catch {
        Logger.shared.error("Error opening document at \(destinationURL): \(error)")
      }
    }
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
