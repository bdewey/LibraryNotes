// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import SnapKit
import SwiftUI
import UIKit

protocol BookImporterViewControllerDelegate: AnyObject {
  func bookImporter(_ bookImporter: BookImporterViewController, didStartImporting count: Int)
  func bookImporter(_ bookImporter: BookImporterViewController, didProcess partialCount: Int, of totalCount: Int)
  func bookImporterDidFinishImporting(_ bookImporter: BookImporterViewController)
}

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

  private func importBooks(from urls: [URL], downloadImages: Bool, dryRun: Bool) {
    guard let url = urls.first else {
      Logger.shared.error("Could not find a notebook view controller in the hierarchy")
      return
    }
    Logger.shared.info("Importing books from \(urls)")
    do {
      let data = try Data(contentsOf: url)
      let libraryThingBooks = Array(try JSONDecoder().decode([Int: LibraryThingBook].self, from: data).values)
      let books = libraryThingBooks.map { Book($0) }
      delegate?.bookImporter(self, didStartImporting: books.count)
      bookImporter.importBooks(books: books, dryRun: dryRun, downloadImages: downloadImages) { [self] processed, total in
        if processed == total || processed % 5 == 0 {
          Logger.shared.info("Processed \(processed) of \(total) books")
        }
        self.delegate?.bookImporter(self, didProcess: processed, of: total)
      } completion: { [self] in
        Logger.shared.info("Done with import")
        self.delegate?.bookImporterDidFinishImporting(self)
      }
    } catch {
      Logger.shared.error("Error importing LibaryThing file: \(error)")
    }
    dismiss(animated: true)
  }
}
