//
//  QuotesViewController.swift
//  GrailDiary
//
//  Created by Brian Dewey on 5/15/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import SnapKit
import UIKit

/// Displays a list of quotes.
final class QuotesViewController: UIViewController {
  public var quotes: [ContentFromNote] = [] {
    didSet {
      var snapshot = NSDiffableDataSourceSnapshot<Int, ContentFromNote>()
      snapshot.appendSections([0])
      snapshot.appendItems(quotes)
      dataSource.apply(snapshot)
    }
  }

  private lazy var layout: UICollectionViewLayout = {
    var config = UICollectionLayoutListConfiguration(appearance:
      .insetGrouped)
    config.backgroundColor = .grailBackground
    return UICollectionViewCompositionalLayout.list(using: config)
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, ContentFromNote> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ContentFromNote> { cell, _, quote in
      cell.contentConfiguration = QuoteContentConfiguration(quote: quote)

      var background = UIBackgroundConfiguration.listPlainCell()
      background.backgroundColor = .grailBackground
      cell.backgroundConfiguration = background
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

    [
      collectionView,
    ].forEach(view.addSubview)

    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
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

    let stack = UIStackView(arrangedSubviews: [quoteLabel])
    [
      stack,
    ].forEach(addSubview)

    stack.snp.makeConstraints { make in
      make.top.bottom.equalToSuperview().inset(8)
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

  private func apply(configuration: UIContentConfiguration) {
    guard let quoteContentConfiguration = configuration as? QuoteContentConfiguration else {
      return
    }
    quoteLabel.attributedText = ParsedAttributedString(
      string: String(quoteContentConfiguration.quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace),
      settings: .plainText(textStyle: .body)
    )
  }
}
