// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CodableCSV
import Logging
import SnapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

  private func importBooks(from urls: [URL], hashtags: String, downloadImages: Bool, dryRun: Bool) {
    guard let url = urls.first else {
      Logger.shared.error("Could not find a notebook view controller in the hierarchy")
      return
    }
    Logger.shared.info("Importing books from \(urls)")
    do {
      let bookInfo: [(Book, Date)]
      if url.pathExtension == UTType.commaSeparatedText.preferredFilenameExtension {
        bookInfo = try loadCSV(url: url)
      } else {
        bookInfo = try loadJSON(url: url)
      }
      delegate?.bookImporter(self, didStartImporting: bookInfo.count)
      bookImporter.importBooks(books: bookInfo, hashtags: hashtags, dryRun: dryRun, downloadImages: downloadImages) { [self] processed, total in
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

  private func loadJSON(url: URL) throws -> [(Book, Date)] {
    let data = try Data(contentsOf: url)
    let libraryThingBooks = Array(try JSONDecoder().decode([Int: LibraryThingBook].self, from: data).values)
    return libraryThingBooks.map { (Book($0), $0.entrydate?.date ?? Date()) }
  }

  private func loadCSV(url: URL) throws -> [(Book, Date)] {
    let result = try CSVReader.decode(input: url) {
      $0.headerStrategy = .firstLine
    }
    Logger.shared.info("Read \(result.count) rows: \(result.headers)")
    var actualHeaderNames = [ExpectedHeaders: String]()
    for expectedHeader in ExpectedHeaders.allCases {
      for actualHeader in result.headers {
        if actualHeader.trimmingCharacters(in: .whitespaces).compare(expectedHeader.rawValue, options: [.caseInsensitive]) == .orderedSame {
          actualHeaderNames[expectedHeader] = actualHeader
        }
      }
    }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "YYYY/MM/dd"
    guard let titleHeader = actualHeaderNames[.title], let authorHeader = actualHeaderNames[.author] else {
      throw CSVError.missingColumn
    }
    return result.records.compactMap { record -> (Book, Date)? in
      let title = record[titleHeader] ?? ""
      let author = record[authorHeader] ?? ""
      var book = Book(title: title, authors: [author])
      book.isbn = record.value(actualHeaderNames, header: .isbn)
      book.isbn13 = record.value(actualHeaderNames, header: .isbn13)
      book.rating = record.value(actualHeaderNames, header: .rating).flatMap(Int.init)
      book.publisher = record.value(actualHeaderNames, header: .publisher)
      book.numberOfPages = record.value(actualHeaderNames, header: .numberOfPages).flatMap(Int.init)
      book.yearPublished = record.value(actualHeaderNames, header: .yearPublished).flatMap(Int.init)
      book.review = record.value(actualHeaderNames, header: .review)
      let date = record.value(actualHeaderNames, header: .dateAdded).flatMap(dateFormatter.date) ?? Date()
      return (book, date)
    }
  }
}

extension CSVReader.Record {
  func value(_ actualHeaderNames: [ExpectedHeaders: String], header: ExpectedHeaders) -> String? {
    guard let actualHeader = actualHeaderNames[header], let value = self[actualHeader] else { return nil }
    // Look for things encoded as `="something"` and return just the `something`
    if value.hasPrefix("=\""), value.hasSuffix("\"") {
      return String(value.dropFirst(2).dropLast())
    } else {
      return value
    }
  }
}

enum CSVError: String, Error {
  case missingColumn = "The CSV file is missing a required column"
}

enum ExpectedHeaders: String, CaseIterable {
  case title
  case author
  case isbn
  case isbn13
  case rating = "My Rating"
  case publisher
  case numberOfPages = "Number of Pages"
  case yearPublished = "Year Published"
  case dateAdded = "Date Added"
  case review = "My review"
}

struct CSVHeaders {
  var title: String?
  var author: String?
  var isbn: String?
  var isbn13: String?
  var rating: String?
  var publisher: String?
  var numberOfPages: String?
  var dateAdded: String?
  var dateRead: String?
  var review: String?
}
