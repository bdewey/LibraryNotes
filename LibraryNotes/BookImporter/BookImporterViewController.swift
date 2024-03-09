// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import os
import SnapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
protocol BookImporterViewControllerDelegate: AnyObject {
  func bookImporter(_ bookImporter: BookImporterViewController, didStartImporting count: Int)
  func bookImporter(_ bookImporter: BookImporterViewController, didProcess partialCount: Int, of totalCount: Int)
  func bookImporterDidFinishImporting(_ bookImporter: BookImporterViewController)
}

/// Displays a form that lets the user pick a file with book data to import and set parameters for the import job.
final class BookImporterViewController: UIViewController {
  init(database: NoteDatabase) {
    self.bookImporter = BookImporter(database: database, apiKey: ApiKey.googleBooks)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  weak var delegate: BookImporterViewControllerDelegate?
  private lazy var importForm = UIHostingController(rootView: ImportForm(importAction: importBooks))
  private let bookImporter: BookImporter

  override func viewDidLoad() {
    super.viewDidLoad()
    addChild(importForm)
    importForm.didMove(toParent: self)
    view.addSubview(importForm.view)
    importForm.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }

  private func importBooks(importRequest: BookImportRequest<URL>) {
    Task {
      let url = importRequest.item
      Logger.shared.info("Importing books from \(importRequest.item)")
      do {
        guard let importSource = try importRequest.importSource else {
          throw CocoaError(.fileNoSuchFile)
        }
        switch importSource {
        case .augmentedBooks(let books):
          importBooks(books, importRequest: importRequest)
        case .database(let url):
          try await importDatabase(at: url)
        }
        dismiss(animated: true)
      } catch {
        Logger.shared.error("Error importing \(url): \(error)")
        let alertViewController = UIAlertController(title: "Error", message: "Unexpected error importing books from \(importRequest.item.lastPathComponent)", preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
          self?.dismiss(animated: true)
        }
        alertViewController.addAction(okButton)
        present(alertViewController, animated: true)
      }
    }
  }

  private func importBooks(_ bookInfo: [AugmentedBook], importRequest: BookImportRequest<some Any>) {
    delegate?.bookImporter(self, didStartImporting: bookInfo.count)
    Task {
      await bookImporter.importBooks(request: importRequest.replacingItem(bookInfo)) { [self] processed, total in
        if processed == total || processed % 5 == 0 {
          Logger.shared.info("Processed \(processed) of \(total) books")
        }
        self.delegate?.bookImporter(self, didProcess: processed, of: total)
      }
      Logger.shared.info("Done with import")
      delegate?.bookImporterDidFinishImporting(self)
    }
  }

  private func importDatabase(at url: URL) async throws {
    guard url != bookImporter.database.fileURL else {
      throw CocoaError(.fileWriteFileExists)
    }
    let sourceDatabase = try await NoteDatabase(fileURL: url, authorDescription: "Importer")
    try bookImporter.database.merge(other: sourceDatabase)
  }
}

private enum ImportSource {
  case augmentedBooks([AugmentedBook])
  case database(URL)
}

private extension BookImportRequest where Item == URL {
  /// What are we importing?
  var importSource: ImportSource? {
    get throws {
      let values = try item.resourceValues(forKeys: [.contentTypeKey])
      switch values.contentType {
      case .none:
        return nil
      case .some(.libnotes):
        return .database(item)
      case .some(.kvcrdt):
        return .database(item)
      case .some(.json):
        return .augmentedBooks(try loadJSON(url: item))
      case .some(.commaSeparatedText):
        return .augmentedBooks(try AugmentedBook.loadGoodreadsCSV(url: item))
      default:
        return nil
      }
    }
  }

  private func loadJSON(url: URL) throws -> [AugmentedBook] {
    let data = try Data(contentsOf: url)
    let libraryThingBooks = Array(try JSONDecoder().decode([Int: LibraryThingBook].self, from: data).values)
    return libraryThingBooks.map { AugmentedBook($0) }
  }
}
