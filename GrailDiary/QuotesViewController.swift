// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import GRDB
import GRDBCombine
import Logging
import SnapKit
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

  private let database: NoteDatabase
  private var quoteSubscription: AnyCancellable?

  /// This is the set of *all* eligible quote identifiers ot show. We will show a subset of these.
  public var quoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      shuffleQuotes()
    }
  }

  /// This is the set of *visible* quote identifiers -- a randomly selected subset from `quoteIdentifiers`
  private var visibleQuoteIdentifiers: [ContentIdentifier] = [] {
    willSet {
      quoteSubscription = nil
    }
    didSet {
      do {
        quoteSubscription = try database.queryPublisher(for: attributedQuotesQuery(for: quoteIdentifiers))
          .sink(receiveCompletion: { error in
            Logger.shared.error("Received error completion from quotes query: \(error)")
          }, receiveValue: { [weak self] quotes in
            self?.updateSnapshot(with: quotes)
          })
      } catch {
        Logger.shared.error("Unexpected error fetching quotes: \(error)")
      }
    }
  }

  /// Turns a set of queries for quote IDs into a content query.
  private func attributedQuotesQuery(for quoteIdentifiers: [ContentIdentifier]) -> QueryInterfaceRequest<ContentFromNote> {
    ContentRecord
      .filter(keys: quoteIdentifiers.map { $0.keyArray })
      .including(required: ContentRecord.note)
      .asRequest(of: ContentFromNote.self)
  }

  /// Updates the collection view given quotes.
  private func updateSnapshot(with quotes: [ContentFromNote]) {
    var snapshot = NSDiffableDataSourceSnapshot<Int, ContentFromNote>()
    snapshot.appendSections([0])
    snapshot.appendItems(quotes.shuffled())
    dataSource.apply(snapshot)
  }

  private lazy var layout: UICollectionViewLayout = {
    var config = UICollectionLayoutListConfiguration(appearance:
      .plain
    )
    config.showsSeparators = false
    config.backgroundColor = .grailBackground
    return UICollectionViewCompositionalLayout.list(using: config)
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.delegate = self
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, ContentFromNote> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ContentFromNote> { cell, _, quote in
      cell.contentConfiguration = QuoteContentConfiguration(quote: quote)
      cell.backgroundConfiguration = UIBackgroundConfiguration.clear()
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, ContentFromNote>(collectionView: collectionView) { collectionView, indexPath, quote in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: quote)
    }
    return dataSource
  }()

  // MARK: - View lifecycle

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .grailBackground

    let shuffleButton = UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(shuffleQuotes))
    navigationItem.rightBarButtonItem = shuffleButton

    [
      collectionView,
    ].forEach(view.addSubview)

    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }

  @objc private func shuffleQuotes() {
    visibleQuoteIdentifiers = Array(quoteIdentifiers.shuffled().prefix(5))
  }
}

// MARK: - NotebookSecondaryViewController
extension QuotesViewController: NotebookSecondaryViewController {
  private struct ViewControllerState: Codable {
    let title: String?
    let quoteIdentifiers: [ContentIdentifier]
  }

  public static var notebookDetailType: String { "QuotesViewController" }

  private var currentViewControllerState: ViewControllerState {
    ViewControllerState(title: title, quoteIdentifiers: quoteIdentifiers)
  }

  public func userActivityData() throws -> Data {
    try JSONEncoder().encode(currentViewControllerState)
  }

  public static func makeFromUserActivityData(data: Data, database: NoteDatabase) throws -> QuotesViewController {
    let quoteVC = QuotesViewController(database: database)
    let viewControllerState = try JSONDecoder().decode(ViewControllerState.self, from: data)
    quoteVC.quoteIdentifiers = viewControllerState.quoteIdentifiers
    quoteVC.title = viewControllerState.title
    return quoteVC
  }
}

// MARK: - UICollectionViewDelegate

extension QuotesViewController: UICollectionViewDelegate {
  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let content = dataSource.itemIdentifier(for: indexPath) else { return nil }
    let viewNoteAction = UIAction(title: "View Book", image: UIImage(systemName: "book")) { [notebookViewController] _ in
      Logger.shared.info("Navigating to book ____")
      notebookViewController?.pushNote(with: content.note.id)
    }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      UIMenu(title: "", children: [viewNoteAction])
    }
  }
}

// MARK: - Private

private struct QuoteContentConfiguration: UIContentConfiguration {
  let quote: ContentFromNote

  func makeContentView() -> UIView & UIContentView {
    QuoteView(configuration: self)
  }

  func updated(for state: UIConfigurationState) -> QuoteContentConfiguration {
    self
  }
}

private final class QuoteView: UIView, UIContentView {
  var configuration: UIContentConfiguration {
    didSet {
      apply(configuration: configuration)
    }
  }

  init(configuration: QuoteContentConfiguration) {
    self.configuration = configuration
    super.init(frame: .zero)

    let stack = UIStackView(arrangedSubviews: [quoteLabel, attributionLabel])
    stack.axis = .vertical
    stack.spacing = 8
    [
      stack,
    ].forEach(addSubview)

    stack.snp.makeConstraints { make in
      make.top.equalToSuperview().inset(8)
      make.bottom.equalToSuperview().inset(40)
      make.left.right.equalTo(readableContentGuide)
    }
    apply(configuration: configuration)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let quoteLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()

  private let attributionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()

  private func apply(configuration: UIContentConfiguration) {
    guard let quoteContentConfiguration = configuration as? QuoteContentConfiguration else {
      return
    }
    let (formattedQuote, attributionFragment) = ParsedAttributedString(
      string: String(quoteContentConfiguration.quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace),
      settings: .plainText(textStyle: .body, fontDesign: .serif)
    ).decomposedChapterAndVerseAnnotation
    quoteLabel.attributedText = formattedQuote

    // Strip the opening & closing parenthesis of attributionFragment
    let trimmedFragment = attributionFragment
      .strippingLeadingAndTrailingWhitespace
      .dropFirst()
      .dropLast()
    if trimmedFragment.split(separator: " ").count > 1 {
      // It looks like the attribution fragment is more than one word. Use that exclusively as the attribution.
      attributionLabel.attributedText = ParsedAttributedString(string: String(trimmedFragment), settings: .plainText(textStyle: .caption1))
    } else {
      let attributionMarkdown = [
        String(quoteContentConfiguration.quote.note.title.strippingLeadingAndTrailingWhitespace),
        String(trimmedFragment),
      ].filter { !$0.isEmpty }.joined(separator: ", ")
      attributionLabel.attributedText = ParsedAttributedString(string: attributionMarkdown, settings: .plainText(textStyle: .caption1))
    }
  }
}