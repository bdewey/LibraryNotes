// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import LibraryNotesCore
import LibraryNotesUI
import os
import SwiftUI
import UIKit

/// Displays a list of quotes.
public final class QuotesViewController: UIViewController {
  public init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let database: NoteDatabase

  /// This is the set of *all* eligible quote identifiers ot show. We will show a subset of these.
  public var quoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      shuffleQuotes()
    }
  }

  /// This is the set of *visible* quote identifiers -- a randomly selected subset from `quoteIdentifiers`
  private var visibleQuoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      do {
        let quotes = try database.attributedQuotes(for: visibleQuoteIdentifiers)
          .shuffled()
          .map(QuoteDisplayModel.init)
        updateQuotes(quotes)
      } catch {
        Logger.shared.error("Unexpected error fetching quotes: \(error)")
      }
    }
  }

  private var displayedQuotes: [QuoteDisplayModel] = []

  private lazy var quoteHostingController = UIHostingController(rootView: makeQuoteListView())

  // MARK: - View lifecycle

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .grailBackground

    let shuffleButton = UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(shuffleQuotes))
    navigationItem.rightBarButtonItem = shuffleButton

    addChild(quoteHostingController)
    view.addSubview(quoteHostingController.view)
    quoteHostingController.didMove(toParent: self)

    quoteHostingController.view.backgroundColor = .grailBackground
    quoteHostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      quoteHostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      quoteHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      quoteHostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      quoteHostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    updateQuotes(displayedQuotes)
  }

  @objc private func shuffleQuotes() {
    visibleQuoteIdentifiers = Array(quoteIdentifiers.shuffled().prefix(5))
  }

  private func updateQuotes(_ quotes: [QuoteDisplayModel]) {
    displayedQuotes = quotes
    guard isViewLoaded else { return }
    quoteHostingController.rootView = makeQuoteListView()
  }

  private func makeQuoteListView() -> QuoteListView {
    QuoteListView(
      quotes: displayedQuotes,
      onViewBook: { [weak self] quote in
        self?.notebookViewController?.pushNote(with: quote.noteId, selectedText: quote.selectedText, autoFirstResponder: true)
      },
      onShare: { [weak self] quote in
        self?.shareQuote(quote)
      }
    )
  }
}

// MARK: - NotebookSecondaryViewController

extension QuotesViewController: NotebookSecondaryViewController {
  private struct ViewControllerState: Codable {
    let title: String?
    let quoteIdentifiers: [ContentIdentifier]
  }

  public nonisolated static var notebookDetailType: String { "QuotesViewController" }

  public var shouldShowWhenCollapsed: Bool { true }

  private var currentViewControllerState: ViewControllerState {
    ViewControllerState(title: title, quoteIdentifiers: quoteIdentifiers)
  }

  public func userActivityData() throws -> Data {
    try JSONEncoder().encode(currentViewControllerState)
  }

  public static func makeFromUserActivityData(data: Data, database: NoteDatabase, coverImageCache: CoverImageCache) throws -> QuotesViewController {
    let quoteVC = QuotesViewController(database: database)
    let viewControllerState = try JSONDecoder().decode(ViewControllerState.self, from: data)
    quoteVC.quoteIdentifiers = viewControllerState.quoteIdentifiers
    quoteVC.title = viewControllerState.title
    return quoteVC
  }
}

// MARK: - Sharing

extension QuotesViewController {
  private func shareQuote(_ quote: QuoteDisplayModel) {
    let content = QuoteCardView(model: quote, mode: .share)
      .frame(width: 584, alignment: .topLeading)
      .padding(8)
      .background(Color.grailBackground)

    let renderer = ImageRenderer(content: content)
    renderer.scale = view.window?.screen.scale ?? UIScreen.main.scale
    let activityItems: [Any]
    if let image = renderer.uiImage {
      activityItems = [image, quote.quoteText]
    } else {
      activityItems = [quote.quoteText]
    }

    let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    let popover = activityViewController.popoverPresentationController
    popover?.sourceView = view
    popover?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    present(activityViewController, animated: true, completion: nil)
  }
}
