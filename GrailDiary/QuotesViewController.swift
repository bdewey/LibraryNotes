// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import SnapKit
import UIKit

/// Displays a list of quotes.
final class QuotesViewController: UIViewController {
  public var quotes: [ContentFromNote] = [] {
    didSet {
      shuffleQuotes()
    }
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

  override func viewDidLoad() {
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
}

// MARK: - UICollectionViewDelegate

extension QuotesViewController: UICollectionViewDelegate {
  func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let content = dataSource.itemIdentifier(for: indexPath) else { return nil }
    let viewNoteAction = UIAction(title: "View Book", image: UIImage(systemName: "book")) { [notebookViewController] _ in
      Logger.shared.info("Navigating to book ____")
      notebookViewController?.openNote(with: content.note.id)
    }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      UIMenu(title: "", children: [viewNoteAction])
    }
  }
}

// MARK: - Private

private extension QuotesViewController {
  @objc func shuffleQuotes() {
    var snapshot = NSDiffableDataSourceSnapshot<Int, ContentFromNote>()
    snapshot.appendSections([0])
    snapshot.appendItems(Array(quotes.shuffled().prefix(5)))
    dataSource.apply(snapshot)
  }
}

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
