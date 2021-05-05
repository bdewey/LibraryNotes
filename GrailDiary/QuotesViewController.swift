// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GRDB
import Logging
import SwiftUI
import UIKit

public extension Logger {
  static let quotes: Logger = {
    var logger = Logger(label: "org.brians-brain.grail-diary.quotes")
    logger.logLevel = .debug
    return logger
  }()
}

/// Displays selections of quotes from the database.
final class QuotesViewController: UIViewController {
  init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let database: NoteDatabase
  private var quotesListHost: UIHostingController<QuotesList>!

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .grailBackground
    do {
      let quotes = try database.attributedQuotes()
      Logger.quotes.debug("Found \(quotes.count) quotes")
      let viewModels = quotes.map(QuoteViewModel.init)
      quotesListHost = UIHostingController(rootView: QuotesList(quotes: viewModels))
      view.addSubview(quotesListHost.view)
      addChild(quotesListHost)
      quotesListHost.didMove(toParent: self)
      quotesListHost.view.snp.makeConstraints { make in
        make.edges.equalToSuperview()
      }
    } catch {
      Logger.quotes.error("Unexpected error getting quotes: \(error)")
    }
  }
}

private struct AttributedQuote: Decodable, FetchableRecord {
  var key: String
  var text: String
  var note: NoteRecord
}

private extension QuoteViewModel {
  init(_ attributedQuote: AttributedQuote) {
    self.id = attributedQuote.note.id + ":" + attributedQuote.key
    self.quote = ParsedString(attributedQuote.text, grammar: MiniMarkdownGrammar.shared)
    self.attributionTitle = ParsedString(attributedQuote.note.title, grammar: MiniMarkdownGrammar.shared)
  }
}

private extension NoteDatabase {
  func attributedQuotes() throws -> [AttributedQuote] {
    guard let dbQueue = dbQueue else { throw Error.databaseIsNotOpen }
    let request = ContentRecord
      .filter(ContentRecord.Columns.role == "prompt=quote")
      .including(required: ContentRecord.note)
      .asRequest(of: AttributedQuote.self)
    return try dbQueue.read { db in
      try request.fetchAll(db)
    }
  }
}
